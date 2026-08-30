/// Жанр трека. Сырые строки — это то, что лежит в базе у каждого трека и события
/// прослушивания, поэтому их нельзя переименовывать: жанр у уже собранной
/// фонотеки после этого не прочитается. Новые случаи добавлять безопасно.
///
/// Порядок объявления — это порядок в списке выбора, поэтому случаи стоят
/// семьями: поп, рок, хип-хоп, электроника и так далее. `other` замыкает список.
enum Genre: String, CaseIterable, Codable {
    // Поп
    case pop = "Pop"
    case jpop = "J-Pop"
    case kpop = "K-Pop"
    case cityPop = "City Pop"
    case anime = "Anime"
    case synthpop = "Synth-Pop"
    case hyperpop = "Hyperpop"

    // Рок
    case alternative = "Alternative"
    case rock = "Rock"
    case uarock = "Ukrainian Rock"
    case rurock = "Russian Rock"
    case indie = "Indie"
    case grunge = "Grunge"
    case shoegaze = "Shoegaze"
    case postRock = "Post-Rock"
    case punk = "Punk"
    case postPunk = "Post-Punk"
    case emo = "Emo"
    case metal = "Metal"
    case metalcore = "Metalcore"

    // Хип-хоп
    case hipHop = "Hip-Hop"
    case rap = "Rap"
    case archievecore = "Arhievecore"
    case trap = "Trap"
    case drill = "Drill"
    case phonk = "Phonk"
    case grime = "Grime"
    case lofi = "Lo-Fi"

    // Электроника и клуб
    case electronic = "Electronic"
    case club = "Club"
    case dance = "Dance"
    case edm = "EDM"
    case eurodance = "Eurodance"
    case house = "House"
    case deepHouse = "Deep House"
    case techHouse = "Tech House"
    case techno = "Techno"
    case trance = "Trance"
    case hardstyle = "Hardstyle"
    case hardbass = "Hard Bass"
    case dubstep = "Dubstep"
    case drumAndBass = "Drum & Bass"
    case garage = "UK Garage"
    case jerseyClub = "Jersey Club"
    case breakbeat = "Breakbeat"
    case synthwave = "Synthwave"
    case ambient = "Ambient"

    // Ритм-н-блюз и соседи
    case rnb = "R&B"
    case soul = "Soul"
    case funk = "Funk"
    case disco = "Disco"
    case gospel = "Gospel"

    // Джаз, блюз, классика
    case jazz = "Jazz"
    case blues = "Blues"
    case classical = "Classical"
    case soundtrack = "Soundtrack"

    // Народное и мировое
    case folk = "Folk"
    case country = "Country"
    case reggae = "Reggae"
    case latin = "Latin"
    case afrobeats = "Afrobeats"

    case other = "Other"
}
