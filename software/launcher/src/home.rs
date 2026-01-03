use std::{rc::Rc, time::Duration};

use chrono::{Local, Timelike};
use slint::{ComponentHandle, Timer, TimerMode, VecModel};
use sysinfo::{CpuRefreshKind, MemoryRefreshKind, RefreshKind, System};

use crate::ui::{DatetimeAdapter, Launcher, UsageAdapter};

pub fn setup(launcher: &Launcher) -> Timer {
    let timer = Timer::default();
    let mut system = System::new_with_specifics(
        RefreshKind::nothing()
            .with_cpu(CpuRefreshKind::nothing().with_cpu_usage())
            .with_memory(MemoryRefreshKind::everything()),
    );

    timer.start(TimerMode::Repeated, Duration::from_millis(500), {
        let launcher_ref = launcher.as_weak();

        move || {
            if let Some(launcher_ref) = launcher_ref.upgrade() {
                update_datetime(&launcher_ref.global::<DatetimeAdapter>());
                update_usage(&mut system, &launcher_ref.global::<UsageAdapter>());
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

fn update_usage(system: &mut System, adapter: &UsageAdapter) {
    system.refresh_cpu_usage();

    let cpus_usages = system
        .cpus()
        .iter()
        .map(|cpu| cpu.cpu_usage())
        .collect::<VecModel<_>>();

    let memory_usage = (system.used_memory() / system.total_memory()) as f32 * 100.0;
    let swap_usage = (system.used_swap() / system.total_swap()) as f32 * 100.0;

    adapter.set_cpus_usage(Rc::new(cpus_usages).into());
    adapter.set_memory_usage(memory_usage);
    adapter.set_swap_usage(swap_usage);
}
