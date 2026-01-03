mod home;

use std::error::Error;

use slint::ComponentHandle;

pub mod ui {
    slint::include_modules!();
}

fn main() -> Result<(), Box<dyn Error>> {
    let launcher = ui::Launcher::new()?;
    let _timer = home::setup(&launcher);

    launcher.run()?;

    Ok(())
}
