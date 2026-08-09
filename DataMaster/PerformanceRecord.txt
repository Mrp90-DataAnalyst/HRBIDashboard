let
  Source = Excel.Workbook(File.Contents("C:\data\HR_Source\04_Performance\Performance_Ratings_2025.xlsx"), null, true),
  #"Navigation 1" = Source{[Item = "Sheet1", Kind = "Sheet"]}[Data],
  #"Promoted headers" = Table.PromoteHeaders(#"Navigation 1", [PromoteAllScalars = true]),
  #"Changed column type" = Table.TransformColumnTypes(#"Promoted headers", {{"EmployeeID", type text}, {"Q1_2025", type number}, {"Q2_2025", type number}, {"Q3_2025", type number}, {"Q4_2025", type number}}),
    #"Unpivoted Columns" = Table.UnpivotOtherColumns(#"Changed column type", {"EmployeeID"}, "Attribute", "Value"),
    #"Renamed Columns" = Table.RenameColumns(#"Unpivoted Columns",{{"Attribute", "Quarter"}, {"Value", "Rating"}}),
    #"Filtered Rows" = Table.SelectRows(#"Renamed Columns", each true)
in
    #"Filtered Rows"