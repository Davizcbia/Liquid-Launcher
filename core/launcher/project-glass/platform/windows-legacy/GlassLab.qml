import QtQuick
import QtQuick.Controls
import QtQuick.Effects

ApplicationWindow {
    id: lab
    width: 1060
    height: 720
    minimumWidth: 840
    minimumHeight: 580
    visible: true
    title: "Project Glass · 09.22 · Isolated Glass Lab"
    color: "#0C1929"

    property bool blurOn: true
    property bool sidebarOn: false
    property real scenePan: 0
    property real sceneZoom: 1
    readonly property color textColor: "#F0F7FF"

    // The backdrop is a *separate* render tree. No children of the glass
    // layers are ever included in the sampled texture (prevents feedback).
    Item {
        id: scene
        anchors.fill: parent
        clip: true
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#0D4764" }
                GradientStop { position: 0.55; color: "#103348" }
                GradientStop { position: 1; color: "#242039" }
            }
        }
        Rectangle {
            x: 90 + lab.scenePan * 0.4; y: 150
            width: 440; height: 440; radius: 220
            color: "#263A8BBB"
            opacity: 0.35
        }
        Item {
            id: movingCards
            x: lab.scenePan
            y: 0
            scale: lab.sceneZoom
            transformOrigin: Item.Center
            width: scene.width
            height: scene.height
            Repeater {
                model: [
                    { x: 170, y: 188, w: 310, h: 250, name: "The Rebirth", detail: "Fabric 1.21.5" },
                    { x: 600, y: 265, w: 260, h: 200, name: "Survival", detail: "Minecraft 1.20.1" },
                    { x: 350, y: 455, w: 235, h: 175, name: "Creative", detail: "Minecraft 26.3" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    x: modelData.x; y: modelData.y
                    width: modelData.w; height: modelData.h
                    radius: 28
                    color: "#C0447190"
                    border.width: 1
                    border.color: "#709AD9F4"
                    Column {
                        x: 23; y: 22; spacing: 15
                        Text { text: "◆"; color: "#79D7FF"; font.pixelSize: 32 }
                        Text { text: modelData.name; color: lab.textColor; font.pixelSize: 25; font.bold: true }
                        Text { text: modelData.detail; color: "#A6C9DD"; font.pixelSize: 15 }
                    }
                }
            }
        }
    }

    // Full-window source and full-window mask MUST share the same coordinate
    // system. No sourceRect, scale or per-panel crop is involved.
    ShaderEffectSource {
        id: sceneTexture
        sourceItem: scene
        anchors.fill: parent
        hideSource: false
        live: true
        visible: false
        recursive: false
    }

    Item {
        id: blurShape
        anchors.fill: parent
        visible: false
        Rectangle {
            x: testPanel.x
            y: testPanel.y
            width: testPanel.width
            height: testPanel.height
            radius: testPanel.radius
            color: "white"
        }
    }
    ShaderEffectSource {
        id: blurMask
        sourceItem: blurShape
        anchors.fill: parent
        hideSource: true
        live: true
        visible: false
    }

    // Test shader has the same dimensions and origin as the captured scene.
    // Only the rounded test panel is revealed by the mask.
    MultiEffect {
        id: liveBlur
        anchors.fill: parent
        source: sceneTexture
        visible: lab.blurOn
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 0.65
        blurMax: 32
        maskEnabled: true
        maskSource: blurMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.0
    }

    Rectangle {
        id: testPanel
        z: 8
        width: Math.min(590, lab.width - (lab.sidebarOn ? 325 : 130))
        height: 108
        x: lab.sidebarOn ? 282 + (lab.width - 282 - width) / 2 : (lab.width - width) / 2
        y: lab.height - height - 108
        radius: 32
        color: lab.blurOn ? "#58395B78" : "#AA243F55"
        border.width: 1
        border.color: "#A5E7FAFF"
        Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.InOutCubic } }
        Row {
            anchors.centerIn: parent
            spacing: 20
            Rectangle {
                width: 58; height: 58; radius: 18
                color: "#477DA3C1"
                Text { anchors.centerIn: parent; text: "◆"; color: "#80D9FF"; font.pixelSize: 30 }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text { text: "Backdrop alignment test"; color: lab.textColor; font.pixelSize: 18; font.bold: true }
                Text { text: lab.blurOn ? "Live blur on · full-window coordinates" : "Blur off · safe fallback"; color: "#C2D9E8"; font.pixelSize: 13 }
            }
        }
    }

    Rectangle {
        id: topPanel
        z: 9
        x: (lab.width - width) / 2
        y: 95
        width: 490; height: 62; radius: 31
        color: "#BE1E425A"
        border.color: "#A0C9E1EF"
        Row {
            anchors.centerIn: parent; spacing: 16
            Text { text: "PROJECT GLASS"; color: lab.textColor; font.pixelSize: 15; font.bold: true }
            Text { text: "09.22  ·  GLASS LAB"; color: "#93C9E8"; font.pixelSize: 13 }
        }
    }

    // This sidebar is a layout test only. It deliberately has no live blur.
    Rectangle {
        z: 10
        x: lab.sidebarOn ? 0 : -width
        y: 0
        width: 282; height: lab.height
        color: "#D82A516A"
        border.color: "#668DA7B8"
        Behavior on x { NumberAnimation { duration: 370; easing.type: Easing.InOutCubic } }
        Column {
            x: 24; y: 100; spacing: 24
            Text { text: "Project Glass"; font.pixelSize: 25; font.bold: true; color: lab.textColor }
            Text { text: "Launch"; font.pixelSize: 16; color: lab.textColor }
            Text { text: "Download"; font.pixelSize: 16; color: lab.textColor }
            Text { text: "Settings"; font.pixelSize: 16; color: lab.textColor }
        }
    }

    Rectangle {
        z: 20
        x: 26
        y: lab.height - height - 18
        width: lab.width - 52
        height: 72
        radius: 25
        color: "#E0183146"
        border.color: "#628FB0C4"
        Row {
            anchors.centerIn: parent
            spacing: 20
            Text { text: "Blur"; color: lab.textColor; anchors.verticalCenter: parent.verticalCenter }
            Switch { checked: lab.blurOn; onToggled: lab.blurOn = checked }
            Text { text: "Sidebar"; color: lab.textColor; anchors.verticalCenter: parent.verticalCenter }
            Switch { checked: lab.sidebarOn; onToggled: lab.sidebarOn = checked }
            Text { text: "Move cards"; color: lab.textColor; anchors.verticalCenter: parent.verticalCenter }
            Slider { width: 150; from: -220; to: 220; value: lab.scenePan; onMoved: lab.scenePan = value }
            Text { text: "Scale"; color: lab.textColor; anchors.verticalCenter: parent.verticalCenter }
            Slider { width: 105; from: 0.7; to: 1.3; value: lab.sceneZoom; onMoved: lab.sceneZoom = value }
            Button { text: "Reset"; onClicked: { lab.scenePan = 0; lab.sceneZoom = 1 } }
        }
    }
}
