const API_URL = 'https://plantsnap-app.azurewebsites.net';
let selectedFile = null;
let currentUser = null;
let lastIdentification = null;
let savedPlantsList = [];

// Tab Switching Mechanism
function switchTab(tabId) {
    const panes = document.querySelectorAll('.tab-pane');
    panes.forEach(pane => {
        pane.classList.remove('active');
        pane.style.display = 'none';
    });

    const activePane = document.getElementById(tabId);
    if (activePane) {
        activePane.style.display = 'block';
        // Trigger reflow for animation
        void activePane.offsetWidth;
        activePane.classList.add('active');
    }

    const navItems = document.querySelectorAll('.nav-item');
    navItems.forEach(item => {
        item.classList.remove('active');
    });

    const activeNavItem = document.querySelector(`.nav-item[data-tab="${tabId}"]`);
    if (activeNavItem) {
        activeNavItem.classList.add('active');
    }

    // Scroll tab content wrapper to top
    document.querySelector('.tab-content-wrapper').scrollTop = 0;
}

// Authenticated check
async function checkAuth() {
    try {
        const res = await fetch(`${API_URL}/.auth/me`);
        if (res.ok) {
            const data = await res.json();
            if (data && data.length > 0) {
                const claims = data[0].user_claims;
                const name = claims.find(c => c.typ === 'name')?.val || 'Utilizador';
                const email = claims.find(c => c.typ === 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress')?.val || '';
                const picture = claims.find(c => c.typ === 'picture')?.val || '';
                currentUser = { name, email, picture };
                updateUI();
                loadGarden();
            } else {
                currentUser = null;
                updateUI();
            }
        } else {
            currentUser = null;
            updateUI();
        }
    } catch (e) {
        currentUser = null;
        updateUI();
    }
}

// Update UI panels based on auth state
function updateUI() {
    const isAuth = currentUser !== null;

    // Home Tab
    const homeUserCard = document.getElementById('homeUserCard');
    const homeGuestCard = document.getElementById('homeGuestCard');
    if (isAuth) {
        homeUserCard.style.display = 'block';
        homeGuestCard.style.display = 'none';
        document.getElementById('homeUserName').textContent = currentUser.name;
        document.getElementById('homeUserAvatar').src = currentUser.picture || "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100' viewBox='0 0 100 100'><circle cx='50' cy='50' r='50' fill='%231a5c38'/><path d='M50 55a15 15 0 1 0 0-30 15 15 0 0 0 0 30zm0 5c-13.3 0-40 6.7-40 20v10h80v-10c0-13.3-26.7-20-40-20z' fill='white'/></svg>";
    } else {
        homeUserCard.style.display = 'none';
        homeGuestCard.style.display = 'block';
    }

    // Identify Tab Result Auth state
    const authenticatedContent = document.getElementById('authenticatedContent');
    const anonymousContent = document.getElementById('anonymousContent');
    if (isAuth) {
        authenticatedContent.style.display = 'block';
        anonymousContent.style.display = 'none';
    } else {
        authenticatedContent.style.display = 'none';
        anonymousContent.style.display = 'block';
    }

    // Garden Tab Auth panels
    const authenticatedGarden = document.getElementById('authenticatedGarden');
    const anonymousGarden = document.getElementById('anonymousGarden');
    if (isAuth) {
        authenticatedGarden.style.display = 'block';
        anonymousGarden.style.display = 'none';
    } else {
        authenticatedGarden.style.display = 'none';
        anonymousGarden.style.display = 'block';
        document.getElementById('emptyGarden').style.display = 'none';
    }

    // Profile Tab
    const authenticatedProfile = document.getElementById('authenticatedProfile');
    const anonymousProfile = document.getElementById('anonymousProfile');
    if (isAuth) {
        authenticatedProfile.style.display = 'block';
        anonymousProfile.style.display = 'none';
        document.getElementById('profileName').textContent = currentUser.name;
        document.getElementById('profileEmail').textContent = currentUser.email;
        document.getElementById('profileAvatar').src = currentUser.picture || "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='100' height='100' viewBox='0 0 100 100'><circle cx='50' cy='50' r='50' fill='%231a5c38'/><path d='M50 55a15 15 0 1 0 0-30 15 15 0 0 0 0 30zm0 5c-13.3 0-40 6.7-40 20v10h80v-10c0-13.3-26.7-20-40-20z' fill='white'/></svg>";
        loadPreferences();
    } else {
        authenticatedProfile.style.display = 'none';
        anonymousProfile.style.display = 'block';
    }
}

// Load and Toggle notification preferences
async function loadPreferences() {
    if (!currentUser) return;
    try {
        const res = await fetch(`${API_URL}/preferences`);
        if (res.ok) {
            const data = await res.json();
            document.getElementById('notificationToggle').checked = data.notificationsEnabled;
        }
    } catch (e) {
        console.error("Erro ao carregar preferências:", e);
    }
}

async function toggleNotifications() {
    if (!currentUser) return;
    const enabled = document.getElementById('notificationToggle').checked;
    try {
        const res = await fetch(`${API_URL}/preferences`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ notificationsEnabled: enabled })
        });
        if (!res.ok) {
            document.getElementById('notificationToggle').checked = !enabled;
            alert("Erro ao guardar preferências.");
        }
    } catch (e) {
        console.error("Erro ao guardar preferências:", e);
        document.getElementById('notificationToggle').checked = !enabled;
        alert("Erro de ligação ao guardar preferências.");
    }
}

// Login & Logout redirects
function login() {
    window.location.href = `${API_URL}/.auth/login/google?post_login_redirect_uri=${API_URL}/app`;
}

// Custom logouts
function logout() {
    window.location.href = `${API_URL}/.auth/logout?post_logout_redirect_uri=/app`;
}

function openPlantModal(id) {
    const p = savedPlantsList.find(x => x.id === id);
    if(!p) return;
    document.getElementById('modalImage').src = p.imageUrl;
    document.getElementById('modalImage').onerror = function() { this.src='data:image/svg+xml;utf8,<svg xmlns=%27http://www.w3.org/2000/svg%27 width=%27100%27 height=%27100%27 viewBox=%270 0 100 100%27><rect width=%27100%25%27 height=%27100%25%27 fill=%27%23e8f5e9%27/><path d=%27M48.8 84.8A24.5 24.5 0 0 1 44.6 36.1C64.6 32.3 69.8 30.5 76.8 22c3.5 7 7 14.6 7 28 0 19.3-16.7 35-35 35ZM17.2 88.3c0-10.5 6.5-18.8 17.8-21 15.5-3 24.3-8.3 27.8-11.8%27 fill=%27none%27 stroke=%27%231a5c38%27 stroke-width=%274%27 stroke-linecap=%27round%27 stroke-linejoin=%27round%27/></svg>'; };
    document.getElementById('modalTitle').textContent = p.plantName;
    document.getElementById('modalProbability').textContent = p.probability;
    document.getElementById('modalWatering').textContent = p.watering || 'Não disponível na altura da identificação.';
    document.getElementById('modalDescription').textContent = p.description || 'Não disponível na altura da identificação.';
    document.getElementById('plantDetailModal').style.display = 'flex';
}

// Modal closing
function closePlantModal() {
    document.getElementById('plantDetailModal').style.display = 'none';
}

// File loading handler
function handleFile(event) {
    const file = event.target.files[0];
    if (!file) return;
    selectedFile = file;
    const reader = new FileReader();
    reader.onload = (e) => {
        const preview = document.getElementById('preview');
        preview.src = e.target.result;
        preview.style.display = 'block';
        document.getElementById('placeholder').style.display = 'none';
    };
    reader.readAsDataURL(file);
    document.getElementById('btnIdentify').disabled = false;
    document.getElementById('resultCard').style.display = 'none';
    document.getElementById('error').style.display = 'none';
    document.getElementById('success').style.display = 'none';
}

// Identify action call
async function identify() {
    if (!selectedFile) return;

    // UI Visual Loading state
    const uploadArea = document.getElementById('uploadArea');
    uploadArea.classList.add('scanning');

    document.getElementById('loading').style.display = 'flex';
    document.getElementById('resultCard').style.display = 'none';
    document.getElementById('error').style.display = 'none';
    document.getElementById('success').style.display = 'none';
    document.getElementById('btnIdentify').disabled = true;

    const formData = new FormData();
    formData.append('file', selectedFile);

    try {
        const response = await fetch(`${API_URL}/identify`, { method: 'POST', body: formData });
        const data = await response.json();
        if (!response.ok) throw new Error(data.detail || 'Erro ao identificar planta.');

        lastIdentification = data;

        // Set name & probability
        document.getElementById('plantName').textContent = data.plantName;
        document.getElementById('probability').textContent = `${data.probability}%`;

        // Set description
        document.getElementById('plantDescription').textContent = data.description || 'Não foi encontrada nenhuma descrição detalhada para esta planta.';

        // Show target preview image inside resultHero
        const resultImage = document.getElementById('resultImage');
        resultImage.innerHTML = '';
        const img = new Image();
        img.style.cssText = 'width:100%;height:200px;object-fit:cover;';
        img.src = document.getElementById('preview').src;
        resultImage.appendChild(img);

        document.getElementById('resultCard').style.display = 'block';
        document.getElementById('resultCard').scrollIntoView({ behavior: 'smooth', block: 'nearest' });

        // Keep auth action elements correctly mapped
        if (currentUser) {
            document.getElementById('authenticatedContent').style.display = 'block';
            document.getElementById('anonymousContent').style.display = 'none';
        } else {
            document.getElementById('authenticatedContent').style.display = 'none';
            document.getElementById('anonymousContent').style.display = 'block';
        }
    } catch (err) {
        const errorDiv = document.getElementById('error');
        errorDiv.textContent = err.message;
        errorDiv.style.display = 'block';
        errorDiv.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    } finally {
        uploadArea.classList.remove('scanning');
        document.getElementById('loading').style.display = 'none';
        document.getElementById('btnIdentify').disabled = false;
    }
}

// Save identified plant
async function savePlant() {
    if (!selectedFile || !lastIdentification) return;
    const formData = new FormData();
    formData.append('file', selectedFile);
    formData.append('plantName', lastIdentification.plantName);
    formData.append('probability', lastIdentification.probability);
    formData.append('description', lastIdentification.description || '');
    formData.append('watering', lastIdentification.watering || '');

    try {
        const res = await fetch(`${API_URL}/save`, { method: 'POST', body: formData });
        const data = await res.json();
        if (!res.ok) throw new Error(data.detail || 'Erro ao salvar a planta.');

        const s = document.getElementById('success');
        s.textContent = '🌱 Planta guardada no teu jardim virtual!';
        s.style.display = 'block';
        s.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        setTimeout(() => s.style.display = 'none', 4000);

        loadGarden();
    } catch (err) {
        const e = document.getElementById('error');
        e.textContent = err.message;
        e.style.display = 'block';
        e.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
}

// Load Garden List
async function loadGarden() {
    if (!currentUser) return;
    try {
        const res = await fetch(`${API_URL}/garden`);
        const data = await res.json();

        savedPlantsList = data.plants || [];

        // Update profile stats counter
        document.getElementById('profilePlantCount').textContent = savedPlantsList.length;

        const list = document.getElementById('gardenList');
        const emptyGarden = document.getElementById('emptyGarden');

        if (savedPlantsList.length === 0) {
            list.innerHTML = '';
            emptyGarden.style.display = 'block';
            return;
        }

        emptyGarden.style.display = 'none';

        list.innerHTML = savedPlantsList.map(p => `
            <div class="plant-card" onclick="openPlantModal('${p.id}')" style="cursor: pointer;">
                <img class="plant-card-img" src="${p.imageUrl}" alt="${p.plantName}" onerror="this.src='data:image/svg+xml;utf8,<svg xmlns=%27http://www.w3.org/2000/svg%27 width=%27100%27 height=%27100%27 viewBox=%270 0 100 100%27><rect width=%27100%25%27 height=%27100%25%27 fill=%27%23e8f5e9%27/><path d=%27M48.8 84.8A24.5 24.5 0 0 1 44.6 36.1C64.6 32.3 69.8 30.5 76.8 22c3.5 7 7 14.6 7 28 0 19.3-16.7 35-35 35ZM17.2 88.3c0-10.5 6.5-18.8 17.8-21 15.5-3 24.3-8.3 27.8-11.8%27 fill=%27none%27 stroke=%27%231a5c38%27 stroke-width=%274%27 stroke-linecap=%27round%27 stroke-linejoin=%27round%27/></svg>'">
                <div class="plant-card-info">
                    <h4 class="plant-card-title">${p.plantName}</h4>
                    <span class="plant-card-badge">${p.probability}% confiança</span>
                </div>
            </div>
        `).join('');
    } catch (e) {
        console.error("Erro ao carregar o jardim:", e);
    }
}

// Initial setup
document.addEventListener('DOMContentLoaded', () => {
    checkAuth();
});
