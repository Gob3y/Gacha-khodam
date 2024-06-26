document.getElementById('kodamForm').addEventListener('submit', function(event) {
    event.preventDefault();
    const name = document.getElementById('name').value;

    fetch('/khodam/khodam.txt')
        .then(response => response.text())
        .then(data => {
            const kodams = data.split('\n').map(kodam => kodam.trim()).filter(kodam => kodam);
            const randomKodam = kodams[Math.floor(Math.random() * kodams.length)];
            const resultElement = document.getElementById('result');
            resultElement.innerText = `Nama : ${name}\nKhodam : ${randomKodam}`;
            resultElement.classList.add('show');

            const tableBody = document.getElementById('checkedTableBody');
            const newRow = tableBody.insertRow();
            const nameCell = newRow.insertCell(0);
            const khodamCell = newRow.insertCell(1);
            nameCell.textContent = name;
            khodamCell.textContent = randomKodam;
            saveToLocalStorage(name, randomKodam);

        })
        .catch(error => {
            console.error('Error fetching the kodam list:', error);
            const resultElement = document.getElementById('result');
            resultElement.innerText = 'Error fetching the kodam list.';
            resultElement.classList.add('show');
        });
});

document.getElementById('clearTable').addEventListener('click', function() {
    localStorage.removeItem('khodamData');
    document.getElementById('checkedTableBody').innerHTML = '';
});

function saveToLocalStorage(name, khodam) {
    const data = JSON.parse(localStorage.getItem('khodamData')) || [];
    data.push({ name: name, khodam: khodam });
    localStorage.setItem('khodamData', JSON.stringify(data));
}

function loadTableData() {
    const data = JSON.parse(localStorage.getItem('khodamData')) || [];
    const tableBody = document.getElementById('checkedTableBody');
    data.forEach(item => {
        const newRow = tableBody.insertRow();
        const nameCell = newRow.insertCell(0);
        const khodamCell = newRow.insertCell(1);
        nameCell.textContent = item.name;
        khodamCell.textContent = item.khodam;
    });
}

document.addEventListener('DOMContentLoaded', loadTableData);
