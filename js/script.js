document.addEventListener('DOMContentLoaded', function() {
    const form = document.getElementById('kodamForm');
    const resultElement = document.getElementById('result');
    const checkedTableBody = document.querySelector('#checkedTable tbody');
    const clearTableButton = document.getElementById('clearTable');

    const checkedNames = JSON.parse(localStorage.getItem('checkedNames')) || [];

    function updateCheckedTable() {
        checkedTableBody.innerHTML = '';
        checkedNames.forEach(({ name, kodam }) => {
            const row = document.createElement('tr');
            row.innerHTML = <td>${name}</td><td>${kodam}</td>;
            checkedTableBody.appendChild(row);
        });
    }

    function fetchKodamList() {
        return fetch('khodam/khodam.txt')
            .then(response => {
                if (!response.ok) {
                    throw new Error(HTTP error! status: ${response.status});
                }
                return response.text();
            })
            .then(data => data.split('\n').map(kodam => kodam.trim()).filter(kodam => kodam));
    }

    form.addEventListener('submit', function(event) {
        event.preventDefault();
        const name = document.getElementById('name').value;

        fetchKodamList()
            .then(kodams => {
                const randomKodam = kodams[Math.floor(Math.random() * kodams.length)];
                resultElement.innerText = Nama: ${name}\nKhodam: ${randomKodam};
                resultElement.classList.add('show');

                checkedNames.push({ name, kodam: randomKodam });
                localStorage.setItem('checkedNames', JSON.stringify(checkedNames));
                updateCheckedTable();
            })
            .catch(error => {
                console.error('Error fetching the kodam list:', error);
                resultElement.innerText = 'Error fetching the kodam list.';
                resultElement.classList.add('show');
            });
    });

    clearTableButton.addEventListener('click', function() {
        localStorage.removeItem('checkedNames');
        checkedNames.length = 0;
        updateCheckedTable();
    });

    updateCheckedTable();
});
