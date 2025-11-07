const RNAME = 'ghost-stash';
let LOCALE = {
	addStash: 'Depo Ekle',
	stashList: 'Depo Listesi',
	everyone: 'Herkes',
	jobs: 'Meslek',
	gangs: 'Çete',
	access: 'Erişim',
	filterAll: 'Tümü',
	filterJobs: 'Mesleğe Göre',
	filterGangs: 'Çeteye Göre',
	filterEveryone: 'Herkes Açık',
	label: 'Başlık',
	coords: 'Koordinat',
	type: 'Tip',
	save: 'Kaydet',
	cancel: 'İptal',
};
let STASHES = [];
let IS_ADMIN = false;
let currentTab = 'all';
let UI_TITLE = 'Ghost Stash';
let EDITING = null;
let searchQuery = '';

const el = (q) => document.querySelector(q);
const els = (q) => document.querySelectorAll(q);

const $container = el('#container');
const $list = el('#list');
const $btnClose = el('#btn-close');
const $btnAdd = el('#btn-add');
const $searchInput = el('#search-input');

const $modal = el('#modal');
const $modalClose = el('#modal-close');
const $btnCancel = el('#btn-cancel');
const $btnSave = el('#btn-save');
const $inpLabel = el('#inp-label');
const $selType = el('#sel-type');
const $wrapJob = el('#wrap-job');
const $wrapGang = el('#wrap-gang');
const $inpJob = el('#inp-job');
const $inpGang = el('#inp-gang');
const $inpCoords = el('#inp-coords');
const $btnCoords = el('#btn-getcoords');
const $inpRadius = el('#inp-radius');

// Image icon paths
const ICON_OPEN = 'assets/img/access_stash.png';
const ICON_TP = 'assets/img/teleport.png';
const ICON_DEL = 'assets/img/trash.png';

function nui(path, data = {}) {
	return fetch(`https://${RNAME}/${path}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify(data),
	});
}

function openUI(stashes, locale, isAdmin, uiTitle) {
	STASHES = Array.isArray(stashes) ? stashes : [];
	if (locale) LOCALE = locale;
    IS_ADMIN = !!isAdmin;
    if (uiTitle) UI_TITLE = uiTitle;
	applyLocale();
	$container.classList.remove('hidden');
	render();
}

function closeUI() {
	$container.classList.add('hidden');
	$modal.classList.add('hidden');
	nui('close');
}

function applyLocale() {
    el('.title').textContent = UI_TITLE || 'Ghost Stash';
    el('#btn-add').textContent = LOCALE.addStash || 'Depo Ekle';
    const $count = document.getElementById('count');
    if ($count) $count.textContent = `${LOCALE.stashList || 'Depo Listesi'}: ${STASHES.length}`;
	// Tabs text update
	const map = {
		all: LOCALE.filterAll || 'Tümü',
		jobs: LOCALE.filterJobs || 'Mesleğe Göre',
		gangs: LOCALE.filterGangs || 'Çeteye Göre',
		everyone: LOCALE.filterEveryone || 'Herkes Açık',
	};
	els('.tab').forEach((t) => {
		const key = t.dataset.tab;
		if (map[key]) t.textContent = map[key];
	});
	// Modal labels
	el('#modal-title').textContent = LOCALE.addStash || 'Depo Ekle';
	el('#lbl-label').textContent = LOCALE.label || 'Başlık';
	el('#lbl-type').textContent = LOCALE.type || 'Tip';
	el('#lbl-coords').textContent = LOCALE.coords || 'Koordinat';
	el('#lbl-job').textContent = LOCALE.labelJob || 'Meslek';
	el('#lbl-gang').textContent = LOCALE.labelGang || 'Çete';
	el('#lbl-radius').textContent = LOCALE.labelRadius || 'Bölge Yarıçapı (m)';
	$btnCancel.textContent = LOCALE.cancel || 'İptal';
	$btnSave.textContent = LOCALE.save || 'Kaydet';
	// Select options (Type dropdown)
	const $selType = el('#sel-type');
	if ($selType) {
		const currentValue = $selType.value;
		$selType.innerHTML = '';
		const everyoneOpt = document.createElement('option');
		everyoneOpt.value = 'everyone';
		everyoneOpt.textContent = LOCALE.everyone || 'Herkes';
		$selType.appendChild(everyoneOpt);
		const jobOpt = document.createElement('option');
		jobOpt.value = 'job';
		jobOpt.textContent = LOCALE.jobs || 'Meslek';
		$selType.appendChild(jobOpt);
		const gangOpt = document.createElement('option');
		gangOpt.value = 'gang';
		gangOpt.textContent = LOCALE.gangs || 'Çete';
		$selType.appendChild(gangOpt);
		$selType.value = currentValue || 'everyone';
	}
	// Placeholders
	if ($inpLabel) $inpLabel.placeholder = LOCALE.placeholderLabel || 'Örn: Polis Silah Deposu';
	if ($inpJob) $inpJob.placeholder = LOCALE.placeholderJob || 'Örn: police';
	if ($inpGang) $inpGang.placeholder = LOCALE.placeholderGang || 'Örn: ballas';
	if ($inpCoords) $inpCoords.placeholder = LOCALE.placeholderCoords || 'x,y,z';
	if ($inpRadius) $inpRadius.placeholder = LOCALE.placeholderRadius || 'Örn: 2.0';
	// Buttons
	if ($btnCoords) $btnCoords.textContent = LOCALE.btnUseMyLocation || 'Konumumu Kullan';
	// Search input
	if ($searchInput) $searchInput.placeholder = LOCALE.searchPlaceholder || 'Depo ara...';
}

function render() {
	let filtered = STASHES;
	if (currentTab === 'jobs') filtered = STASHES.filter((s) => s.accessType === 'job');
	else if (currentTab === 'gangs') filtered = STASHES.filter((s) => s.accessType === 'gang');
	else if (currentTab === 'everyone') filtered = STASHES.filter((s) => s.accessType === 'everyone');

	// Arama filtresi
	if (searchQuery && searchQuery.trim() !== '') {
		const query = searchQuery.toLowerCase().trim();
		filtered = filtered.filter((s) => {
			const label = (s.label || '').toLowerCase();
			return label.includes(query);
		});
	}

    $list.innerHTML = '';
    const $count = document.getElementById('count');
    if ($count) $count.textContent = `${LOCALE.stashList || 'Depo Listesi'}: ${filtered.length}`;

	for (const s of filtered) {
		const card = document.createElement('div');
		card.className = 'card';
		const tags = [
			`<span class="tag">${s.accessType || 'everyone'}</span>`,
			(s.job ? `<span class="tag">${s.job}</span>` : ''),
			(s.gang ? `<span class="tag">${s.gang}</span>` : ''),
		].filter(Boolean).join(' ');
        card.innerHTML = `
			<h4>${s.label || 'Stash'}</h4>
			<div class="meta">${s.coords ? `${s.coords.x?.toFixed?.(1)||s.coords.x}, ${s.coords.y?.toFixed?.(1)||s.coords.y}, ${s.coords.z?.toFixed?.(1)||s.coords.z}` : ''}</div>
			<div class="row">${tags}</div>
            <div class="actions">
                ${IS_ADMIN ? `<button class=\"btn-icon primary btn-open\" title=\"${LOCALE.tooltipOpen || 'Open Stash'}\" aria-label=\"${LOCALE.tooltipOpen || 'Open Stash'}\"><img class=\"ico-img\" src=\"${ICON_OPEN}\" alt=\"open\" /></button>` : ''}
                <button class=\"btn-icon primary btn-tp\" title=\"${LOCALE.tooltipTeleport || 'Teleport'}\" aria-label=\"${LOCALE.tooltipTeleport || 'Teleport'}\"><img class=\"ico-img\" src=\"${ICON_TP}\" alt=\"tp\" /></button>
                ${IS_ADMIN ? `<button class=\"btn-icon primary btn-edit\" title=\"${LOCALE.tooltipEdit || 'Edit Stash'}\" aria-label=\"${LOCALE.tooltipEdit || 'Edit Stash'}\"><img class=\"ico-img\" src=\"assets/img/edit.png\" alt=\"edit\" /></button>` : ''}
                ${IS_ADMIN ? `<button class=\"btn-icon primary btn-del\" title=\"${LOCALE.tooltipDelete || 'Delete Stash'}\" aria-label=\"${LOCALE.tooltipDelete || 'Delete Stash'}\"><img class=\"ico-img\" src=\"${ICON_DEL}\" alt=\"del\" /></button>` : ''}
            </div>
		`;
        // Butonların title attribute'larını güncelle (tooltip çevirileri için)
        if (IS_ADMIN) {
            const openBtn = card.querySelector('.btn-open');
            if (openBtn) {
                openBtn.title = LOCALE.tooltipOpen || 'Open Stash';
                openBtn.setAttribute('aria-label', LOCALE.tooltipOpen || 'Open Stash');
                openBtn.addEventListener('click', () => {
                    nui('openStash', s);
                });
            }
            const eb = card.querySelector('.btn-edit');
            if (eb) {
                eb.title = LOCALE.tooltipEdit || 'Edit Stash';
                eb.setAttribute('aria-label', LOCALE.tooltipEdit || 'Edit Stash');
                eb.addEventListener('click', () => {
                    EDITING = s;
                    $inpLabel.value = s.label || '';
                    $selType.value = s.accessType || 'everyone';
                    $wrapJob.style.display = s.accessType === 'job' ? 'block' : 'none';
                    $wrapGang.style.display = s.accessType === 'gang' ? 'block' : 'none';
                    $inpJob.value = s.job || '';
                    $inpGang.value = s.gang || '';
                    if (s.coords) $inpCoords.value = `${(s.coords.x||0).toFixed(2)}, ${(s.coords.y||0).toFixed(2)}, ${(s.coords.z||0).toFixed(2)}`;
                    if ($inpRadius) $inpRadius.value = s.radius != null ? s.radius : '';
                    openModal();
                });
            }
        }
        const tpBtn = card.querySelector('.btn-tp');
        if (tpBtn) {
            tpBtn.title = LOCALE.tooltipTeleport || 'Teleport';
            tpBtn.setAttribute('aria-label', LOCALE.tooltipTeleport || 'Teleport');
            tpBtn.addEventListener('click', () => {
                if (s.coords) {
                    nui('teleportTo', { coords: s.coords });
                }
            });
        }
        if (IS_ADMIN) {
            const delBtn = card.querySelector('.btn-del');
            if (delBtn) {
                delBtn.title = LOCALE.tooltipDelete || 'Delete Stash';
                delBtn.setAttribute('aria-label', LOCALE.tooltipDelete || 'Delete Stash');
                delBtn.addEventListener('click', async () => {
                    try { await nui('deleteStash', { stashId: s.stashId }); } catch {}
                });
            }
        }
		$list.appendChild(card);
	}
}

// TextUI controls
function showTextUI(text) {
	const $t = document.getElementById('textui');
	const $tt = document.getElementById('textui-text');
	if ($tt && text) $tt.textContent = text;
	$t && $t.classList.remove('hidden');
}
function hideTextUI() {
	const $t = document.getElementById('textui');
	$t && $t.classList.add('hidden');
}

function openModal() {
	$modal.classList.remove('hidden');
}
function closeModal() {
	$modal.classList.add('hidden');
}

function parseCoords(text) {
	if (!text) return null;
	const p = text.split(',').map((t) => parseFloat(t.trim()));
	if (p.length >= 3 && p.every((n) => Number.isFinite(n))) {
		return { x: p[0], y: p[1], z: p[2] };
	}
	return null;
}

// Events
window.addEventListener('message', (e) => {
	const data = e.data || {};
    if (data.action === 'openStashMenu') {
        openUI(data.stashes || [], data.locale, data.isAdmin, data.uiTitle);
	}
	if (data.action === 'updateStashes') {
		STASHES = data.stashes || [];
		render();
	}
    if (data.action === 'showTextUI') {
        showTextUI(data.text);
    }
    if (data.action === 'hideTextUI') {
        hideTextUI();
    }
    if (data.action === 'configTextUI') {
        const t = document.getElementById('textui');
        if (t) {
            const align = data.align || 'center';
            const bottom = (typeof data.bottomPercent === 'number' ? data.bottomPercent : 7);
            const side = (typeof data.sidePercent === 'number' ? data.sidePercent : 3);
            t.style.bottom = `${bottom}%`;
            if (align === 'left') {
                t.style.left = `${side}%`;
                t.style.right = '';
                t.style.transform = 'none';
            } else if (align === 'right') {
                t.style.left = '';
                t.style.right = `${side}%`;
                t.style.transform = 'none';
            } else {
                t.style.left = '50%';
                t.style.right = '';
                t.style.transform = 'translateX(-50%)';
            }
            t.style.zIndex = '9999';
            t.style.position = 'fixed';
        }
    }
});

// ESC close
window.addEventListener('keydown', (e) => {
	if (e.key === 'Escape') {
		if (!$modal.classList.contains('hidden')) {
			closeModal();
			return;
		}
		closeUI();
	}
});

// Tabs
els('.tab').forEach((btn) => {
	btn.addEventListener('click', () => {
		els('.tab').forEach((b) => b.classList.remove('active'));
		btn.classList.add('active');
		currentTab = btn.dataset.tab;
		render();
	});
});

// Search input
if ($searchInput) {
	$searchInput.addEventListener('input', (e) => {
		searchQuery = e.target.value || '';
		render();
	});
}

$btnClose.addEventListener('click', closeUI);
$btnAdd.addEventListener('click', () => {
	$inpLabel.value = '';
	$inpJob.value = '';
	$inpGang.value = '';
	$inpCoords.value = '';
	$selType.value = 'everyone';
	$wrapJob.style.display = 'none';
	$wrapGang.style.display = 'none';
    if ($inpRadius) $inpRadius.value = '';
	openModal();
});

$modalClose.addEventListener('click', closeModal);
$btnCancel.addEventListener('click', closeModal);

$selType.addEventListener('change', () => {
	const v = $selType.value;
	$wrapJob.style.display = v === 'job' ? 'block' : 'none';
	$wrapGang.style.display = v === 'gang' ? 'block' : 'none';
});

$btnCoords.addEventListener('click', async () => {
	try {
		const res = await nui('getCoords');
		const pos = await res.json();
		if (pos && typeof pos.x === 'number') {
			$inpCoords.value = `${pos.x.toFixed(2)}, ${pos.y.toFixed(2)}, ${pos.z.toFixed(2)}`;
		}
	} catch {}
});

$btnSave.addEventListener('click', async () => {
	const label = ($inpLabel.value || '').trim();
	const accessType = $selType.value;
	const coords = parseCoords($inpCoords.value);
	const job = ($inpJob.value || '').trim();
	const gang = ($inpGang.value || '').trim();
    const radius = $inpRadius && $inpRadius.value ? parseFloat($inpRadius.value) : null;
	if (!label || !coords) return; // basit validasyon
    if (EDITING && EDITING.stashId) {
        const payload = { label, accessType, coords, job: job || null, gang: gang || null, radius: radius || 1.8, stashId: EDITING.stashId };
        await nui('updateStash', payload);
        EDITING = null;
    } else {
        const payload = { label, accessType, coords, job: job || null, gang: gang || null, radius: radius || 1.8, stashId: `stash_${Date.now()}` };
        await nui('addStash', payload);
    }
	closeModal();
});
