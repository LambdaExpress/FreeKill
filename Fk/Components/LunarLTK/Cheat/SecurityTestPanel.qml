// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Components.LunarLTK

ColumnLayout {
  id: root
  anchors.fill: parent
  spacing: 8

  property var extra_data: ({})
  property string cardDump: ""
  property string statusMessage: ""
  readonly property bool canUseTool: true
  readonly property bool canSendForgedReply: canUseTool
                                             && acceptBox.checked
                                             && roomScene.state === "active"
  signal finish()

  function parseIds(text) {
    const ret = [];
    const parts = String(text ?? "").split(/[\s,;]+/);
    for (const part of parts) {
      if (part === "") continue;
      const value = parseInt(part, 10);
      if (!isNaN(value)) ret.push(value);
    }
    return ret;
  }

  function getHandcardIds(playerId) {
    if (playerId === Self.id && roomScene.dashboard?.handcardArea?.cards) {
      return roomScene.dashboard.handcardArea.cards
        .map(card => card.cid)
        .filter(cid => typeof cid === "number");
    }

    const ids = Ltk.getPlayerHandcards(playerId);
    return Array.isArray(ids) ? ids : [];
  }

  function getDefaultQingnangTarget() {
    const players = roomScene.getPlayerSnapshot();
    const selfPlayer = players.find(player => player.id === Self.id);
    if (selfPlayer && selfPlayer.hp < selfPlayer.maxHp) {
      return selfPlayer.id;
    }

    const wounded = players.find(player => player.hp < player.maxHp);
    return wounded ? wounded.id : -1;
  }

  function formatPlayerName(player) {
    const name = player.screenName && player.screenName.length > 0
      ? player.screenName
      : Lua.tr(player.general || "unknown");
    return `${name} / seat ${player.seatNumber} / id ${player.id}`;
  }

  function formatCardLine(cid) {
    const data = Ltk.getCardData(cid, false);
    const visible = Ltk.cardVisibility(cid);
    if (!data || !data.name) {
      return `  #${cid} unknown visible=${visible}`;
    }
    const number = data.number ? data.number : "";
    return `  #${cid} ${Lua.tr(data.name)}(${data.name}) ${data.suit}${number} ${data.color} visible=${visible}`;
  }

  function refreshCardDump() {
    const lines = [];
    const players = roomScene.getPlayerSnapshot();
    for (const player of players) {
      const ids = getHandcardIds(player.id);
      lines.push(formatPlayerName(player));
      if (ids.length === 0) {
        lines.push("  no tracked handcards");
      } else {
        for (const cid of ids) {
          lines.push(formatCardLine(cid));
        }
      }
      lines.push("");
    }
    cardDump = lines.join("\n");
  }

  function fillSelfHandcards(allCards) {
    const ids = getHandcardIds(Self.id);
    if (ids.length === 0) return [];
    const selected = allCards ? ids : [ids[0]];
    cardIdsField.text = selected.join(",");
    return selected;
  }

  function fillFirstOtherHandcard() {
    const players = roomScene.getPlayerSnapshot();
    for (const player of players) {
      if (player.id === Self.id) continue;
      const ids = getHandcardIds(player.id);
      if (ids.length > 0) {
        cardIdsField.text = ids[0].toString();
        return;
      }
    }
  }

  function sendForgedReply(skillName, subcards, targets) {
    if (!canSendForgedReply) {
      statusMessage = "当前未满足发送条件：必须是调试构建、本机服务器、已确认免责声明，并且服务端正在等待你的当前请求。";
      return;
    }

    const payload = {
      card: {
        skill: skillName,
        subcards,
      },
      targets,
    };
    ClientInstance.replyToServer("", payload);
    roomScene.state = "notactive";
    statusMessage = `已发送伪造回包：${skillName} cards=[${subcards.join(",")}] targets=[${targets.join(",")}]`;
  }

  function forgeZhiheng() {
    let cards = parseIds(cardIdsField.text);
    if (cards.length === 0) {
      cards = fillSelfHandcards(true);
    }
    if (cards.length === 0) {
      statusMessage = "制衡默认使用自己的全部手牌，但当前没有可用的已追踪手牌 id。";
      return;
    }
    sendForgedReply("zhiheng", cards, []);
  }

  function forgeKurou() {
    sendForgedReply("kurou", [], []);
  }

  function forgeQingnang() {
    let cards = parseIds(cardIdsField.text);
    if (cards.length === 0) {
      cards = fillSelfHandcards(false);
    } else if (cards.length > 1) {
      cards = [cards[0]];
      cardIdsField.text = cards[0].toString();
    }

    if (cards.length === 0) {
      statusMessage = "青囊默认使用自己的第一张手牌，但当前没有可用的已追踪手牌 id。";
      return;
    }

    let targets = parseIds(targetIdsField.text);
    if (targets.length === 0) {
      const target = getDefaultQingnangTarget();
      if (target > 0) {
        targets = [target];
        targetIdsField.text = target.toString();
      }
    } else if (targets.length > 1) {
      targets = [targets[0]];
      targetIdsField.text = targets[0].toString();
    }

    if (targets.length === 0) {
      statusMessage = "青囊默认选择第一个受伤角色，但当前没有可用的受伤目标。";
      return;
    }
    sendForgedReply("qingnang", cards, targets);
  }

  Text {
    Layout.fillWidth: true
    text: "安全测试工具"
    color: "#E4D5A0"
    font.pixelSize: 24
    horizontalAlignment: Text.AlignHCenter
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: disclaimerText.implicitHeight + acceptBox.implicitHeight + 28
    color: "#55310F12"
    border.color: "#C9965A"
    border.width: 1
    radius: 4

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 8

      Text {
        id: disclaimerText
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: "#F0E5DA"
        font.pixelSize: 14
        text: "免责声明：此面板只用于本地授权安全测试，用来验证服务端是否会接受非法客户端回包。不要在公共服务器、未授权房间或真实对局中使用。入口仅在调试构建且连接本机服务器时显示。"
      }

      CheckBox {
        id: acceptBox
        text: "我确认只在本地授权测试环境使用"
        font.pixelSize: 14
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true

    Text {
      Layout.fillWidth: true
      color: "#F0E5DA"
      font.pixelSize: 14
      text: {
        const req = Backend.getRequestData();
        return `server=${Config.serverAddr}:${Config.serverPort} request=${req.id} state=${roomScene.state}`;
      }
    }

    Button {
      text: "刷新卡牌快照"
      enabled: canUseTool
      onClicked: refreshCardDump();
    }
  }

  Text {
    Layout.fillWidth: true
    text: statusMessage
    color: "#F0E5DA"
    font.pixelSize: 14
    wrapMode: Text.WordWrap
  }

  GridLayout {
    Layout.fillWidth: true
    columns: 4

    Text {
      text: "子卡 id"
      color: "#F0E5DA"
      font.pixelSize: 14
    }
    TextField {
      id: cardIdsField
      Layout.fillWidth: true
      placeholderText: "例如：12 或 12,34"
      selectByMouse: true
    }
    Button {
      text: "填自己全部"
      onClicked: fillSelfHandcards(true);
    }
    Button {
      text: "填他人首张"
      onClicked: fillFirstOtherHandcard();
    }

    Text {
      text: "目标 id"
      color: "#F0E5DA"
      font.pixelSize: 14
    }
    TextField {
      id: targetIdsField
      Layout.fillWidth: true
      Layout.columnSpan: 3
      placeholderText: "青囊需要目标时填写，例如：2"
      selectByMouse: true
    }
  }

  RowLayout {
    Layout.fillWidth: true

    Button {
      text: "伪造制衡"
      enabled: canSendForgedReply
      onClicked: forgeZhiheng();
    }
    Button {
      text: "伪造苦肉"
      enabled: canSendForgedReply
      onClicked: forgeKurou();
    }
    Button {
      text: "伪造青囊"
      enabled: canSendForgedReply
      onClicked: forgeQingnang();
    }
  }

  Text {
    Layout.fillWidth: true
    text: canSendForgedReply
      ? "当前可以发送：服务端正在等待你的回包。"
      : "当前不可发送：请确认免责声明，并等待出牌阶段或响应阶段的请求。"
    color: canSendForgedReply ? "#9BE07B" : "#E4D5A0"
    font.pixelSize: 14
    wrapMode: Text.WordWrap
  }

  TextArea {
    Layout.fillWidth: true
    Layout.fillHeight: true
    text: cardDump
    readOnly: true
    wrapMode: TextEdit.NoWrap
    selectByMouse: true
    font.family: "monospace"
    font.pixelSize: 13
  }

  Component.onCompleted: refreshCardDump();
}
