import Foundation
import Testing
@testable import mMusic

/// Неделя на главной: прослушивания ложатся в свой день и свои два часа,
/// а то, что было раньше недели, в неё не попадает.
struct ListeningWeekTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    @Test func sevenDaysEndingToday() {
        let week = ListeningWeek.make(from: [], endingOn: date(4, 15), calendar: calendar)

        #expect(week.days.count == 7)
        #expect(week.days.first?.date == calendar.date(from: DateComponents(year: 2026, month: 9, day: 28)))
        #expect(week.days.last?.date == calendar.startOfDay(for: date(4, 15)))
        #expect(week.days.allSatisfy { $0.slots.count == ListeningWeek.slotsPerDay })
    }

    @Test func playsLandInTheirDayAndSlot() {
        let week = ListeningWeek.make(
            from: [
                (date(4, 9, 30), 200),
                (date(4, 8, 10), 100),
                (date(2, 23, 55), 300),
            ],
            endingOn: date(4, 15),
            calendar: calendar
        )

        // 8:10 и 9:30 — один кусочек «8–10».
        #expect(week.days[6].slots[4] == 300)
        #expect(week.today == 300)
        // Без пяти полночь — последний кусочек позавчерашнего дня.
        #expect(week.days[4].slots[11] == 300)
        #expect(week.total == 600)
        #expect(week.loudestSlot == 300)
    }

    @Test func playsOlderThanAWeekAreLeftOut() {
        let week = ListeningWeek.make(
            // Ровно неделю назад — восьмой день, в семь он уже не входит.
            from: [(date(4, 12).addingTimeInterval(-7 * 24 * 3600), 500)],
            endingOn: date(4, 15),
            calendar: calendar
        )

        #expect(week.total == 0)
    }

    @Test func listeningLabelShowsHoursOnlyWhenThereAreAny() {
        #expect(TimeInterval(47 * 60).listeningLabel == "47 MIN")
        #expect(TimeInterval(120 * 60).listeningLabel == "2 H")
        #expect(TimeInterval(372 * 60).listeningLabel == "6 H 12 MIN")
    }
}
