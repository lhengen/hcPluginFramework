object fraPackageInfo: TfraPackageInfo
  Left = 0
  Top = 0
  Width = 475
  Height = 238
  TabOrder = 0
  OnResize = FrameResize
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 475
    Height = 238
    Align = alClient
    Caption = 'Panel1'
    TabOrder = 0
    object Splitter1: TSplitter
      Left = 186
      Top = 1
      Height = 236
    end
    object Panel5: TPanel
      Left = 1
      Top = 1
      Width = 185
      Height = 236
      Align = alLeft
      Caption = 'Panel5'
      TabOrder = 0
      object lstPackages: TCheckListBox
        Left = 1
        Top = 18
        Width = 183
        Height = 217
        OnClickCheck = lstPackagesClickCheck
        Align = alClient
        Columns = 1
        ItemHeight = 13
        TabOrder = 0
        OnClick = lstPackagesClick
      end
      object hdrPackages: THeaderControl
        Left = 1
        Top = 1
        Width = 183
        Height = 17
        Sections = <
          item
            ImageIndex = -1
            Text = 'Package'
            Width = 100
          end>
        Style = hsFlat
      end
    end
    object Panel4: TPanel
      Left = 189
      Top = 1
      Width = 285
      Height = 236
      Align = alClient
      Caption = 'Panel4'
      TabOrder = 1
      object meProfile: TMemo
        Left = 1
        Top = 17
        Width = 283
        Height = 218
        Align = alClient
        BevelOuter = bvNone
        Color = clHighlightText
        ScrollBars = ssBoth
        TabOrder = 1
      end
      object Panel6: TPanel
        Left = 1
        Top = 1
        Width = 283
        Height = 16
        Align = alTop
        Caption = 'Profile'
        TabOrder = 0
      end
    end
  end
end
