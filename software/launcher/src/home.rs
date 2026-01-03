use std::time::Duration;

use chrono::{Local, Timelike};
use slint::{ComponentHandle, Timer, TimerMode};

use crate::ui::{DatetimeAdapter, Launcher};

pub fn setup(launcher: &Launcher) -> Timer {
    let timer = Timer::default();

    timer.start(TimerMode::Repeated, Duration::from_secs(1), {
        let launcher_ref = launcher.as_weak();

        move || {
            if let Some(launcher_ref) = launcher_ref.upgrade() {
                update_datetime(&launcher_ref.global::<DatetimeAdapter>());
            }
        }
    });

    timer
}

fn update_datetime(adapter: &DatetimeAdapter) {
    let now = Local::now();
    let (meridiem, hour) = now.hour12();

    adapter.set_hour12(hour as _);
    adapter.set_minute(now.minute() as _);
    adapter.set_meridiem(slint::format!("{}", if meridiem { "PM" } else { "AM" }));
    adapter.set_date(slint::format!("{}", now.format("%A, %b %d")));
}
