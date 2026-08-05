document.addEventListener('DOMContentLoaded', () => {
    // Get all elements we need to interact with
    const mainImage = document.getElementById('mainImage');
    const cameraBrand = document.getElementById('cameraBrand');
    const photoDetails = document.getElementById('photoDetails');
    const photoDate = document.getElementById('photoDate');
    const cameraModel = document.getElementById('cameraModel');
    const lensModel = document.getElementById('lensModel');
    const remark = document.getElementById('remark');
    const thumbnailLinks = document.querySelectorAll('.thumbnail-link');
    
    const fullscreenOverlay = document.getElementById('fullscreen-overlay');
    const fullscreenImage = document.getElementById('fullscreen-image');
    const fullscreenClose = document.getElementById('fullscreen-close');
    const fullscreenPrev = document.getElementById('fullscreenPrev');
    const fullscreenNext = document.getElementById('fullscreenNext');
    const fullscreenToggle = document.getElementById('fullscreen-toggle');
    const zoomInButton = document.getElementById('zoom-in-button');
    
    let currentIndex = 0;
    let currentZoomLevel = 1.0;
    let isZoomed = false;

    // Function to update the main photo and its information
    const updateMainPhoto = (index) => {
        // Ensure index is within the valid range
        if (index < 0) {
            index = thumbnailLinks.length - 1;
        } else if (index >= thumbnailLinks.length) {
            index = 0;
        }
        currentIndex = index;

        const link = thumbnailLinks[currentIndex];

        // Get data from the clicked thumbnail's custom data attributes
        const src = link.dataset.src;
        const details = link.dataset.details;
        const date = link.dataset.date;
        const brand = link.dataset.brand;
        const model = link.dataset.model;
        const lens = link.dataset.lens;
        const photoBy = link.dataset.remark;

        // Update the main image and text content
        mainImage.src = src;
        cameraBrand.textContent = brand;
        photoDetails.textContent = details;
        photoDate.textContent = date;
        cameraModel.textContent = model;
        lensModel.textContent = lens;
        remark.textContent = photoBy;
        
        // Update active class on thumbnails
        thumbnailLinks.forEach(item => item.classList.remove('active'));
        link.classList.add('active');

        // Add the new functionality to scroll the thumbnail into view
        // 使用 `scrollIntoView` 方法将当前选中的缩略图滚动到可见区域
        link.scrollIntoView({
            behavior: 'smooth', // 平滑滚动
            block: 'nearest',   // 垂直方向上尽量居中
            inline: 'center'    // 水平方向上居中
        });
    };

    // Add click event listeners to all thumbnail links
    thumbnailLinks.forEach((link, index) => {
        link.addEventListener('click', (e) => {
            e.preventDefault(); // Prevent the link from navigating
            updateMainPhoto(index);
        });
    });

    // Fullscreen functionality
    mainImage.addEventListener('click', () => {
        fullscreenImage.src = mainImage.src;
        fullscreenOverlay.classList.add('active');
    });
    
    fullscreenClose.addEventListener('click', () => {
        fullscreenOverlay.classList.remove('active');
        // Reset zoom when exiting fullscreen
        fullscreenImage.style.transform = 'scale(1)';
        fullscreenImage.style.transformOrigin = 'center center';
        fullscreenImage.classList.remove('zoomed');
        isZoomed = false;
        currentZoomLevel = 1.0;
    });
    
    fullscreenPrev.addEventListener('click', () => {
        updateMainPhoto(currentIndex - 1);
        fullscreenImage.src = mainImage.src;
        // Reset zoom on image change
        fullscreenImage.style.transform = 'scale(1)';
        fullscreenImage.classList.remove('zoomed');
        isZoomed = false;
        currentZoomLevel = 1.0;
    });

    fullscreenNext.addEventListener('click', () => {
        updateMainPhoto(currentIndex + 1);
        fullscreenImage.src = mainImage.src;
        // Reset zoom on image change
        fullscreenImage.style.transform = 'scale(1)';
        fullscreenImage.classList.remove('zoomed');
        isZoomed = false;
        currentZoomLevel = 1.0;
    });
    
    // Toggle browser native fullscreen mode
    fullscreenToggle.addEventListener('click', () => {
        if (!document.fullscreenElement) {
            fullscreenOverlay.requestFullscreen().catch(err => {
                console.error(`Error attempting to enable full-screen mode: ${err.message} (${err.name})`);
            });
        } else {
            document.exitFullscreen();
        }
    });

    // Zoom-in button functionality
    zoomInButton.addEventListener('click', () => {
        currentZoomLevel += 0.5; // Zoom in by 50%
        fullscreenImage.style.transform = `scale(${currentZoomLevel})`;
        fullscreenImage.style.transformOrigin = 'center center';
        fullscreenImage.classList.add('zoomed');
        isZoomed = true;
    });

    // Mouse click to zoom functionality
    fullscreenImage.addEventListener('click', (e) => {
        if (isZoomed) {
            // Reset zoom
            fullscreenImage.style.transform = 'scale(1)';
            fullscreenImage.style.transformOrigin = 'center center';
            fullscreenImage.classList.remove('zoomed');
            isZoomed = false;
            currentZoomLevel = 1.0;
        } else {
            // Calculate click position relative to the image
            const rect = e.target.getBoundingClientRect();
            const x = e.clientX - rect.left; // x position within the element
            const y = e.clientY - rect.top;  // y position within the element

            // Set transform-origin to the clicked point
            fullscreenImage.style.transformOrigin = `${x}px ${y}px`;
            
            // Zoom in by a fixed amount
            currentZoomLevel = 1.5;
            fullscreenImage.style.transform = `scale(${currentZoomLevel})`;
            fullscreenImage.classList.add('zoomed');
            isZoomed = true;
        }
    });

    // Keyboard navigation
    document.addEventListener('keydown', (e) => {
        if (fullscreenOverlay.classList.contains('active')) {
            if (e.key === 'ArrowLeft') {
                fullscreenPrev.click();
            } else if (e.key === 'ArrowRight') {
                fullscreenNext.click();
            } else if (e.key === 'Escape') {
                fullscreenClose.click();
            }
        } else { // Handle keyboard navigation on the main page
            if (e.key === 'ArrowLeft') {
                updateMainPhoto(currentIndex - 1);
            } else if (e.key === 'ArrowRight') {
                updateMainPhoto(currentIndex + 1);
            }
        }
    });

    // Set the first thumbnail as active and load its data on page load
    if (thumbnailLinks.length > 0) {
        updateMainPhoto(0);
    }
});