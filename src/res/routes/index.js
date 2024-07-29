var dialog;
var ws;

function connect() {
    ws = new WebSocket(`ws://${window.location.host}/cmds`);
    ws.addEventListener('open', handleOpen);
    ws.addEventListener('message', handleMessage);
    ws.addEventListener('close', handleClose);
}

function handleOpen() {
    console.log('Connected');
    dialog.close();
}

function handleMessage(msg) {
    console.log('Received: ' + msg);
}

function handleClose() {
    console.log('Disconnected. Trying to reconnect...');
    dialog.showModal();
    switch (ws?.readyState ?? WebSocket.CLOSED) {
        case WebSocket.CONNECTING:
            ws.close();
            break;

        case WebSocket.CLOSED:
            connect();
            return;

        case WebSocket.CLOSING:
            dialog.close();
            return;
    }
    setTimeout(() => {
        handleClose();
    }, 5000);
}

const Send = Object.freeze({
    send(cmd) {
        if (!ws || ws.readyState != WebSocket.OPEN) {
            handleClose();
            return;
        }
        ws.send(cmd);
        console.log("Sent: " + cmd);
    },
    ping() {
        this.send("PING");
    },
    press(key) {
        this.send("PRESS " + key);
    },
    type(msg) {
        this.send("TYPE " + msg);
    },
    volume(vol) {
        if (vol > 0) {
            this.send("VOL up " + vol);
        } else if (vol < 0) {
            this.send("VOL down " + Math.abs(vol));
        } else {
            this.send("VOL mute");
        }
    },
    nav(dir) {
        if (!dir in ["up", "down", "left", "right", "enter", "space", "back", "backspace", "tab", "s-tab"]) return;
        this.send("NAV " + dir);
    },
    media(action) {
        if (!action in ["play", "forward", "backward"]) return;
        this.send("MEDIA " + action);
    },
    extra(action) {
        if (!action in ["maximize", "reload", "windows", "search"]) return;
        this.send("EXTRA " + action);
    },
    shutdown() {
        this.send("SHUTDOWN");
    }
})

window.addEventListener('load', function () {
    // Connection dialog
    dialog = document.querySelector('dialog');
    dialog.showModal();

    // WebSocket connection
    connect();

    // Haptic feedback on press
    const buttons = document.querySelectorAll('button.media');
    for (let i = 0; i < buttons.length; i++) {
        const element = buttons[i];
        element.addEventListener('click', function () {
            navigator.vibrate(50);
        });
    }
});