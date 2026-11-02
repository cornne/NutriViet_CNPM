// NutriViet Prototype Navigation & Interaction Controller
const screenSelector = document.getElementById('screenSelector');
const currentScreenInfo = document.getElementById('currentScreenInfo');
const toggleDeviceBtn = document.getElementById('toggleDeviceBtn');
const deviceFrame = document.getElementById('deviceFrame');

const screenNames = {
  'auth-login': 'UC02: Đăng nhập & Xác thực',
  'auth-register': 'UC01: Đăng ký tài khoản mới',
  'profile-allergens': 'UC04 & UC05: Thiết lập Dị ứng & Bệnh lý nền',
  'scanner-camera': 'UC06: Camera OCR quét bao bì',
  'scanner-crop': 'UC07: Căn chỉnh & Cắt vùng nhãn',
  'scanner-history': 'UC08: Lịch sử quét & Tìm kiếm',
  'alert-red': 'UC09: Cảnh báo ĐỎ (Nguy hiểm / Dị ứng)',
  'alert-yellow': 'UC09: Cảnh báo VÀNG (Thận trọng / Phụ gia)',
  'alert-green': 'UC09: Đánh giá XANH (An toàn)',
  'alternatives-view': 'UC10: Gợi ý sản phẩm thay thế an toàn',
  'diary-nutrition': 'UC11: Nhật ký dinh dưỡng hằng ngày',
  'diary-reaction': 'UC12: Ghi nhận triệu chứng dị ứng',
  'shopping-list': 'UC13 & UC14: Danh sách mua sắm & Yêu thích',
  'crowdsource-submit': 'UC15: Đóng góp sản phẩm mới',
  'crowdsource-report': 'UC16: Báo cáo sai lệch OCR',
  'admin-moderation': 'UC17: Admin - Duyệt đóng góp sản phẩm',
  'admin-dictionary': 'UC18: Admin - Quản lý từ điển phụ gia'
};

function switchScreen(screenId) {
  const allScreens = document.querySelectorAll('.screen-view');
  allScreens.forEach(s => s.classList.add('hidden'));

  const target = document.getElementById(`view-${screenId}`);
  if (target) {
    target.classList.remove('hidden');
    screenSelector.value = screenId;
    if (currentScreenInfo) {
      currentScreenInfo.innerHTML = `Đang hiển thị: <strong>${screenNames[screenId] || screenId}</strong>`;
    }

    // Auto expand frame for desktop admin views
    if (screenId.startsWith('admin-')) {
      deviceFrame.classList.add('expanded');
      toggleDeviceBtn.textContent = 'Chế độ Xem: Desktop Admin Portal';
    } else {
      deviceFrame.classList.remove('expanded');
      toggleDeviceBtn.textContent = 'Chế độ Xem: Mobile Frame';
    }
  }
}

screenSelector.addEventListener('change', (e) => {
  switchScreen(e.target.value);
});

toggleDeviceBtn.addEventListener('click', () => {
  deviceFrame.classList.toggle('expanded');
  const isExp = deviceFrame.classList.contains('expanded');
  toggleDeviceBtn.textContent = isExp ? 'Chế độ Xem: Expanded Desktop' : 'Chế độ Xem: Mobile Frame';
});

// Interactive chip toggle
document.addEventListener('click', (e) => {
  if (e.target.classList.contains('chip')) {
    e.target.classList.toggle('active');
  }
});

// Expose switchScreen globally
window.switchScreen = switchScreen;
