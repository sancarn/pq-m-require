//2024-04-09 Modified by Sancarn. Adapted from code provided by `/u/MonkeyNin` on [reddit](https://www.reddit.com/r/PowerBI/comments/1b43ces/comment/ktn0w8b/).
//Usage:
//require[File]("C:\myFile.m")
//require[Web]("http://someCDN.com/myFile.m")
//
let
    FileContent = (filePath as text, optional options as nullable record) as text =>
        let
            encoding = options[Encoding]? ?? TextEncoding.Utf8,
            bytes = File.Contents(filePath),
            lines = Text.FromBinary(bytes, encoding)
        in
            lines,
    ShowError = (code as text, extent as record) =>
        let
            contents = Lines.FromBinary(code, QuoteStyle.None, false, TextEncoding.Utf8),
            linesCount = extent[EndLineNumber] - extent[StartLineNumber],
            selectedLines = List.Range(contents, extent[StartLineNumber] - 2, linesCount + 2),
            prefix = {"Reason: #[Reason]#", "#Message: #[Message]#", "..."},
            merged = Text.Combine(prefix & selectedLines, "#(cr,lf)"),
            ret = Text.Format(merged, [
                Reason = extent[Reason],
                Message = extent[Message]
            ])
        in
            ret,
    URLContent = (url as text, optional options as nullable record) as text =>
        let
            encoding = options[Encoding]? ?? TextEncoding.Ascii,
            response = Web.Contents(url, options[Web]? ?? []),
            bytes = Binary.Buffer(response),
            lines = Text.FromBinary(bytes, encoding)
        in
            lines,
    EvaluateSnippet = (code as text, optional options as nullable record) as any =>
        let
            environment = options[Environment]? ?? #shared, return = Expression.Evaluate(code, environment)
        in
            return,
    Convert.ScriptExtent.FromError = (err as any) =>
        let
            Split.ScriptExtent = Splitter.SplitTextByEachDelimiter({"[", ",", "-", ",", "]"}, QuoteStyle.None),
            lineData = Split.ScriptExtent(err[Message]),
            ret = [
                StartLineNumber = Number.FromText(lineData{1} ?),
                StartColumnNumber = Number.FromText(lineData{2} ?),
                EndLineNumber = Number.FromText(lineData{3} ?),
                EndColumnNumber = Number.FromText(lineData{4} ?),
                RemainingMessage = lineData{5} ?,
                // shouldn't be more than 1 index?
                Reason = err[Reason],
                Message = err[Message],
                ErrorRecord = err,
                RawText = err[Message]
            ]
        in
            ret,
    Require = [
        Meta = [
            name = "Require",
            repo = "http://github.com/sancarn/pq-m-require",
            version = "1.0.0"
        ],
        File = (filePath as text, optional options as nullable record) as any =>
            (
                let
                    content = FileContent(filePath, options),
                    evaluated = EvaluateSnippet(content, options),
                    Return = try evaluated catch (e) => ShowError(content, Convert.ScriptExtent.FromError(e))
                in
                    Return
            ),
        Web = (url as text, optional options as nullable record) as any =>
            (
                let
                    content = URLContent(url, options),
                    evaluated = EvaluateSnippet(content, options),
                    Return = try evaluated catch (e) => ShowError(content, Convert.ScriptExtent.FromError(e))
                in
                    Return
            )
    ]
in
    Require