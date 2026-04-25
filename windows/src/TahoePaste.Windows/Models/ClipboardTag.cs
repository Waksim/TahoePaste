namespace TahoePaste.Windows.Models;

public enum ClipboardTag
{
    Text,
    Image,
    Link,
    Code,
    Email,
    Phone,
    Password,
    Token,
    DateTime,
    Address,
    File,
    Video,
    Audio,
    Document,
    Pdf,
    Spreadsheet,
    Presentation,
    Archive,
    Folder
}

public static class ClipboardTagExtensions
{
    public static string TitleKey(this ClipboardTag tag) => tag switch
    {
        ClipboardTag.Text => "card.text",
        ClipboardTag.Image => "card.image",
        ClipboardTag.Link => "card.link",
        ClipboardTag.Code => "card.code",
        ClipboardTag.Email => "card.email",
        ClipboardTag.Phone => "card.phone",
        ClipboardTag.Password => "card.password",
        ClipboardTag.Token => "card.token",
        ClipboardTag.DateTime => "card.date_time",
        ClipboardTag.Address => "card.address",
        ClipboardTag.File => "card.file",
        ClipboardTag.Video => "card.video",
        ClipboardTag.Audio => "card.audio",
        ClipboardTag.Document => "card.document",
        ClipboardTag.Pdf => "card.pdf",
        ClipboardTag.Spreadsheet => "card.spreadsheet",
        ClipboardTag.Presentation => "card.presentation",
        ClipboardTag.Archive => "card.archive",
        ClipboardTag.Folder => "card.folder",
        _ => "card.text"
    };

    public static IReadOnlyList<string> SearchKeywords(this ClipboardTag tag) => tag switch
    {
        ClipboardTag.Text => ["text", "texts", "текст", "тексты", "文本", "文字"],
        ClipboardTag.Image => ["image", "images", "picture", "pictures", "изображение", "картинка", "图片", "图像"],
        ClipboardTag.Link => ["link", "links", "url", "urls", "ссылка", "ссылки", "链接", "网址"],
        ClipboardTag.Code => ["code", "snippet", "snippets", "код", "коды", "代码", "代码片段"],
        ClipboardTag.Email => ["email", "e-mail", "mail", "почта", "емейл", "邮箱", "电子邮件"],
        ClipboardTag.Phone => ["phone", "telephone", "number", "телефон", "номер", "号码", "电话"],
        ClipboardTag.Password => ["password", "passcode", "pwd", "пароль", "пароли", "密码", "口令"],
        ClipboardTag.Token => ["token", "secret", "api key", "apikey", "credential", "токен", "секрет", "ключ", "令牌", "密钥"],
        ClipboardTag.DateTime => ["date", "time", "schedule", "meeting", "дата", "время", "расписание", "日期", "时间"],
        ClipboardTag.Address => ["address", "location", "street", "адрес", "локация", "地址", "地点"],
        ClipboardTag.File => ["file", "files", "файл", "файлы", "文件"],
        ClipboardTag.Video => ["video", "movie", "clip", "видео", "ролик", "视频", "影片"],
        ClipboardTag.Audio => ["audio", "music", "sound", "voice", "аудио", "звук", "музыка", "音频", "声音"],
        ClipboardTag.Document => ["document", "documents", "doc", "docs", "документ", "документы", "文档"],
        ClipboardTag.Pdf => ["pdf", "пдф", "pdf文档"],
        ClipboardTag.Spreadsheet => ["spreadsheet", "sheet", "table", "excel", "csv", "таблица", "表格", "电子表格"],
        ClipboardTag.Presentation => ["presentation", "slides", "powerpoint", "презентация", "слайды", "演示", "幻灯片"],
        ClipboardTag.Archive => ["archive", "zip", "rar", "compressed", "архив", "压缩包", "归档"],
        ClipboardTag.Folder => ["folder", "directory", "папка", "директория", "文件夹", "目录"],
        _ => []
    };
}
