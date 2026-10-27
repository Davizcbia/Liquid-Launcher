#include "LauncherLoginStep.h"

#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>

#include "Application.h"
#include "Logging.h"
#include "minecraft/auth/Parsers.h"
#include "net/NetUtils.h"
#include "net/RawHeaderProxy.h"
#include "net/Request.h"

LauncherLoginStep::LauncherLoginStep(AccountData* data) : AuthStep(data) {}

QString LauncherLoginStep::describe()
{
    return tr("Fetching Minecraft access token");
}

void LauncherLoginStep::perform()
{
    const QUrl url("https://api.minecraftservices.com/authentication/login_with_xbox");
    const auto uhs = m_data->mojangservicesToken.extra["uhs"].toString();
    const auto xToken = m_data->mojangservicesToken.token;
    if (uhs.isEmpty() || xToken.isEmpty()) {
        emit finished(AccountTaskState::STATE_FAILED_SOFT, tr("Xbox authorization returned an incomplete token. Please sign in again."));
        return;
    }
    const auto requestBody = QJsonDocument(QJsonObject{
        { "identityToken", QStringLiteral("XBL3.0 x=%1;%2").arg(uhs, xToken) }
    }).toJson(QJsonDocument::Compact);

    auto headers = QList<Net::HeaderPair>{
        { "Content-Type", "application/json" },
        { "Accept", "application/json" },
    };

    auto [request, response] = Net::Request::makeByteArray(url, requestBody);
    m_request = request;
    m_request->addHeaderProxy(std::make_unique<Net::RawHeaderProxy>(headers));
    // A rejected credential exchange must not be replayed by NetJob's download retries.
    m_request->enableAutoRetry(false);
    m_request->setNetwork(APPLICATION->network());
    connect(m_request.get(), &Task::finished, this, [this, response] { onRequestDone(response); });
    m_request->start();
    qDebug() << "Getting Minecraft access token...";
}

void LauncherLoginStep::onRequestDone(QByteArray* response)
{
    if (m_request->error() != QNetworkReply::NoError) {
        const int httpStatus = m_request->replyStatusCode();
        qWarning() << "Minecraft token exchange failed; HTTP" << httpStatus << "network error" << m_request->error();
        if (httpStatus == 401 || httpStatus == 403) {
            const auto error = QJsonDocument::fromJson(*response).object();
            const bool invalidRegistration = error.value("error").toString().contains("Invalid app registration", Qt::CaseInsensitive) ||
                                             error.value("errorMessage").toString().contains("Invalid app registration", Qt::CaseInsensitive);
            emit finished(AccountTaskState::STATE_FAILED_SOFT,
                          invalidRegistration
                              ? tr("Microsoft and Xbox authorization succeeded, but Minecraft rejected this launcher's app registration (HTTP %1). Check Minecraft API access for the configured client ID.").arg(httpStatus)
                              : tr("Microsoft and Xbox authorization succeeded, but Minecraft rejected the token exchange (HTTP %1). The launcher has not signed in. This response alone does not identify the cause.").arg(httpStatus));
            return;
        }
        if (Net::isApplicationError(m_request->error()) && !Net::isServerError(m_request->error())) {
            emit finished(AccountTaskState::STATE_FAILED_SOFT,
                          tr("Failed to get Minecraft access token: %1").arg(m_request->errorString()));
        } else {
            m_data->networkError = m_request->error();
            emit finished(AccountTaskState::STATE_OFFLINE, tr("Failed to get Minecraft access token: %1").arg(m_request->errorString()));
        }
        return;
    }

    const auto tokenResponse = QJsonDocument::fromJson(*response).object();
    if (tokenResponse.value("access_token").toString().isEmpty() || tokenResponse.value("expires_in").toDouble() <= 0 ||
        !Parsers::parseMojangResponse(*response, m_data->yggdrasilToken)) {
        qWarning() << "Could not parse login_with_xbox response...";
        emit finished(AccountTaskState::STATE_FAILED_SOFT, tr("Failed to parse the Minecraft access token response."));
        return;
    }
    emit finished(AccountTaskState::STATE_WORKING, tr("Got Minecraft access token"));
}
