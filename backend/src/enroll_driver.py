from faceid.enrollment import enroll_driver

if __name__ == "__main__":
    driver_id = input("Masukkan driver_id: ").strip()
    enroll_driver(driver_id, camera_index=0)