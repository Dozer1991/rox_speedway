window.addEventListener('message', function (event) {
    const data = event.data;

    if (data.action === 'updateRaceHUD') {
        if ('position' in data && 'total' in data) {
            document.querySelector("#hud-position").innerText = `${data.position}/${data.total}`;
        }

        if ('lap' in data && 'totalLaps' in data) {
            document.querySelector("#hud-lap").innerText = `${data.lap}/${data.totalLaps}`;
        }

        if ('cp' in data && 'totalCp' in data) {
            document.querySelector("#hud-checkpoint").innerText = `${data.cp}/${data.totalCp}`;
        }
    }

    if (data.action === 'toggleRaceHUD') {
        document.getElementById('race-hud').style.display = data.show ? 'block' : 'none';
    }
});
