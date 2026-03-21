import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {

    property alias cfg_pollingInterval: intervalSpinBox.value
    property alias cfg_autoClose: autoCloseCheckBox.checked

    Kirigami.FormLayout {

        QQC2.SpinBox {
            id: intervalSpinBox
            Kirigami.FormData.label: "Polling interval (seconds):"
            from: 1
            to: 10
        }

        QQC2.CheckBox {
            id: autoCloseCheckBox
            Kirigami.FormData.label: "Close popup after changing profile:"
        }
    }
}
