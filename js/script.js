document.getElementById('kodamForm').addEventListener('submit', function(event) {
    event.preventDefault();
    const name = document.getElementById('name').value;

    fetch('/khodam/khodam.txt')
        .then(response => response.text())
        .then(data => {
            const kodams = data.split('\n').map(kodam => kodam.trim()).filter(kodam => kodam);
            const randomKodam = kodams[Math.floor(Math.random() * kodams.length)];
            const resultElement = document.getElementById('result');
            resultElement.innerText = `Nama : ${name}, Kodam : ${randomKodam}`;
            resultElement.innerText = `Khodam : ${randomKodam}`;
            resultElement.classList.add('show');
        })
        .catch(error => {
            console.error('Error fetching the kodam list:', error);
            const resultElement = document.getElementById('result');
            resultElement.innerText = 'Error fetching the kodam list.';
            resultElement.classList.add('show');
        });
});
