let
  Source = Excel.Workbook(File.Contents("C:\Users\data\HR_Source\Separations.xlsx"), null, true),
  #"Navigation 1" = Source{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers",{{"EmployeeID", type text}, {"SeparationDate", type date}, {"SeparationType", type text}, {"Reason", type text}, {"ExitInterviewDone", type text}, {"Rehirable", type text}})
in
  #"Changed column type"