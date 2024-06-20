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

            const tableBody = document.getElementById('checkTableBody');
            const newRow = tableBody.insertRow();
            const nameCell = newRow.insertCell(0);
            const khodamCell = newRow.insertCell(1);
            nameCell.textContent = name;
            khodamCell.textContent = randomKhodam;
            saveToLocalStorage(name, randomKhodam);

        })
        .catch(error => {
            console.error('Error fetching the kodam list:', error);
            const resultElement = document.getElementById('result');
            resultElement.innerText = 'Error fetching the kodam list.';
            resultElement.classList.add('show');
        });
});
