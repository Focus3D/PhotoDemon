VERSION 5.00
Begin VB.Form FormRotate 
   AutoRedraw      =   -1  'True
   BackColor       =   &H80000005&
   BorderStyle     =   4  'Fixed ToolWindow
   Caption         =   " Rotate Image"
   ClientHeight    =   6540
   ClientLeft      =   -15
   ClientTop       =   225
   ClientWidth     =   12105
   BeginProperty Font 
      Name            =   "Tahoma"
      Size            =   8.25
      Charset         =   0
      Weight          =   400
      Underline       =   0   'False
      Italic          =   0   'False
      Strikethrough   =   0   'False
   EndProperty
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   436
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   807
   ShowInTaskbar   =   0   'False
   Begin PhotoDemon.commandBar cmdBar 
      Align           =   2  'Align Bottom
      Height          =   750
      Left            =   0
      TabIndex        =   0
      Top             =   5790
      Width           =   12105
      _ExtentX        =   21352
      _ExtentY        =   1323
      BeginProperty Font {0BE35203-8F91-11CE-9DE3-00AA004BB851} 
         Name            =   "Tahoma"
         Size            =   9.75
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      BackColor       =   14802140
   End
   Begin PhotoDemon.smartOptionButton optRotate 
      Height          =   360
      Index           =   0
      Left            =   6120
      TabIndex        =   4
      Top             =   3330
      Width           =   5715
      _ExtentX        =   10081
      _ExtentY        =   582
      Caption         =   "adjust size to fit rotated image"
      Value           =   -1  'True
   End
   Begin PhotoDemon.fxPreviewCtl fxPreview 
      Height          =   5625
      Left            =   120
      TabIndex        =   3
      Top             =   120
      Width           =   5625
      _ExtentX        =   9922
      _ExtentY        =   9922
      DisableZoomPan  =   -1  'True
   End
   Begin PhotoDemon.smartOptionButton optRotate 
      Height          =   360
      Index           =   1
      Left            =   6120
      TabIndex        =   5
      Top             =   3720
      Width           =   5715
      _ExtentX        =   10081
      _ExtentY        =   582
      Caption         =   "keep image at its present size"
   End
   Begin PhotoDemon.sliderTextCombo sltAngle 
      Height          =   495
      Left            =   6000
      TabIndex        =   6
      Top             =   2280
      Width           =   5895
      _ExtentX        =   10398
      _ExtentY        =   873
      Min             =   -360
      Max             =   360
      SigDigits       =   2
   End
   Begin VB.Label lblRotatedCanvas 
      Appearance      =   0  'Flat
      AutoSize        =   -1  'True
      BackColor       =   &H80000005&
      BackStyle       =   0  'Transparent
      Caption         =   "rotated image size:"
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   12
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      ForeColor       =   &H00404040&
      Height          =   285
      Left            =   6000
      TabIndex        =   2
      Top             =   2880
      Width           =   2025
   End
   Begin VB.Label lblAmount 
      Appearance      =   0  'Flat
      AutoSize        =   -1  'True
      BackColor       =   &H80000005&
      BackStyle       =   0  'Transparent
      Caption         =   "rotation angle:"
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   12
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      ForeColor       =   &H00404040&
      Height          =   285
      Left            =   6000
      TabIndex        =   1
      Top             =   1920
      Width           =   1560
   End
End
Attribute VB_Name = "FormRotate"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'***************************************************************************
'Image Rotation Interface
'Copyright 2012-2015 by Tanner Helland
'Created: 12/November/12
'Last updated: 14/April/14
'Last update: rotate now works with layers!
'
'This tool allows the user to rotate an image at an arbitrary angle in 1/100 degree increments.  FreeImage is
' required for the tool to work, as this relies upon FreeImage to perform the rotation in a fast, efficient
' manner.  The corresponding menu entry for this tool is hidden unless FreeImage is found.  (I could add a
' GDI+ fallback as well, but it's waaaay down my list of priorities.)
'
'At present, the tool assumes that you want to rotate the image around its center.
'
'To rotate a layer instead of the entire image, use the Layer menu.  Rotation is also available in the
' Effect -> Distort menu, which can provide cool artistic effect when combined with selections.
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

'This temporary DIB will be used for rendering the preview
Dim smallDIB As pdDIB

'This dialog can be used to resize the full image, or a single layer.  The requested target will be stored here,
' and can be externally accessed by the ResizeTarget property.
Private m_RotateTarget As PD_ACTION_TARGET

'Custom tooltip class allows for things like multiline, theming, and multiple monitor support
Dim m_Tooltip As clsToolTip

Public Property Let RotateTarget(newTarget As PD_ACTION_TARGET)
    m_RotateTarget = newTarget
End Property

Public Sub RotateArbitrary(ByVal canvasResize As Long, ByVal rotationAngle As Double, Optional ByVal thingToRotate As PD_ACTION_TARGET = PD_AT_WHOLEIMAGE, Optional ByVal isPreview As Boolean = False)
        
    'If the image contains an active selection, disable it before transforming the canvas
    If (thingToRotate = PD_AT_WHOLEIMAGE) And pdImages(g_CurrentImage).selectionActive And (Not isPreview) Then
        pdImages(g_CurrentImage).selectionActive = False
        pdImages(g_CurrentImage).mainSelection.lockRelease
    End If

    'FreeImage uses positive values to indicate counter-clockwise rotation.  While mathematically correct, I find this
    ' unintuitive for casual users.  PD reverses the rotationAngle value so that POSITIVE values indicate CLOCKWISE rotation.
    rotationAngle = -rotationAngle

    Dim tmpDIB As pdDIB
    Set tmpDIB = New pdDIB

    'Double-check that FreeImage exists
    If g_ImageFormats.FreeImageEnabled Then
        
        'Rotation requires quite a few variables, including a number of handles for passing data back-and-forth with FreeImage.
        Dim fi_DIB As Long, returnDIB As Long
        Dim nWidth As Long, nHeight As Long
        
        'One of the FreeImage rotation variants requires an explicit center point; calculate one in advance.
        Dim cx As Double, cy As Double
        
        If isPreview Then
            cx = smallDIB.getDIBWidth / 2
            cy = smallDIB.getDIBHeight / 2
        Else
        
            Select Case thingToRotate
            
                Case PD_AT_WHOLEIMAGE
                    cx = pdImages(g_CurrentImage).Width / 2
                    cy = pdImages(g_CurrentImage).Height / 2
                    
                Case PD_AT_SINGLELAYER
                    cx = pdImages(g_CurrentImage).getActiveDIB.getDIBWidth / 2
                    cy = pdImages(g_CurrentImage).getActiveDIB.getDIBHeight / 2
                    
            End Select
                    
        End If
        
        
        'Normally, I like to use identical code for previews and actual effects.  However, rotating is completely different
        ' for previews (where we do a single rotation of the composited image) vs the full images (independently rotating
        ' each layer, with support functions to null-pad and crop layers as necessary).  As such, there is some code
        ' duplication here, but I believe it makes the code much more readable.
        
        If isPreview Then
            
            'Give FreeImage a handle to our temporary rotation image
            fi_DIB = FreeImage_CreateFromDC(smallDIB.getDIBDC)
            
            'There are two ways to rotate an image - enlarging the canvas to receive the fully rotated copy, or
            ' leaving the image the same size and truncating corners.  These require two different FreeImage functions.
            Select Case canvasResize
            
                'Resize the canvas to accept the new image
                Case 0
                    returnDIB = FreeImage_Rotate(fi_DIB, rotationAngle, RGB(255, 255, 255))
                    
                    nWidth = FreeImage_GetWidth(returnDIB)
                    nHeight = FreeImage_GetHeight(returnDIB)
                    
                'Leave the canvas the same size
                Case 1
                    returnDIB = FreeImage_RotateEx(fi_DIB, rotationAngle, 0, 0, cx, cy, True)
                    
                    nWidth = FreeImage_GetWidth(returnDIB)
                    nHeight = FreeImage_GetHeight(returnDIB)
            
            End Select
            
            'Create a blank DIB to receive the rotated image from FreeImage
            tmpDIB.createBlank nWidth, nHeight, 32
            
            'Ask FreeImage to premultiply the image's alpha data
            FreeImage_PreMultiplyWithAlpha returnDIB
            
            'Copy the bits from the FreeImage DIB to our DIB
            SetDIBitsToDevice tmpDIB.getDIBDC, 0, 0, nWidth, nHeight, 0, 0, 0, nHeight, ByVal FreeImage_GetBits(returnDIB), ByVal FreeImage_GetInfo(returnDIB), 0&
            
            'With the transfer complete, release the FreeImage DIB and unload the library
            If fi_DIB <> 0 Then FreeImage_UnloadEx fi_DIB
            If returnDIB <> 0 Then FreeImage_UnloadEx returnDIB
            
            'Finally, render the preview and erase the temporary DIB to conserve memory
            tmpDIB.renderToPictureBox fxPreview.getPreviewPic
            fxPreview.setFXImage tmpDIB
            
            Set tmpDIB = Nothing
            
        Else
            
            'FreeImage doesn't raise progress events, but we can use the number of layers as
            ' a stand-in progress parameter.
            If thingToRotate = PD_AT_WHOLEIMAGE Then
                Message "Rotating image..."
                SetProgBarMax pdImages(g_CurrentImage).getNumOfLayers
            Else
                Message "Rotating layer..."
                SetProgBarMax 1
            End If
            
            'Iterate through each layer, rotating as we go
            Dim tmpLayerRef As pdLayer
            Dim origOffsetX As Long, origOffsetY As Long
            
            'If we are rotating the entire image, we must handle all layers in turn.  Otherwise, we can handle just
            ' the active layer.
            Dim lInit As Long, lFinal As Long
            
            Select Case thingToRotate
            
                Case PD_AT_WHOLEIMAGE
                    lInit = 0
                    lFinal = pdImages(g_CurrentImage).getNumOfLayers - 1
                
                Case PD_AT_SINGLELAYER
                    lInit = pdImages(g_CurrentImage).getActiveLayerIndex
                    lFinal = pdImages(g_CurrentImage).getActiveLayerIndex
            
            End Select
            
            Dim i As Long
            For i = lInit To lFinal
            
                If thingToRotate = PD_AT_WHOLEIMAGE Then SetProgBarVal i
            
                'Retrieve a pointer to the layer of interest
                Set tmpLayerRef = pdImages(g_CurrentImage).getLayerByIndex(i)
                
                'Remove premultiplied alpha, if any
                tmpLayerRef.layerDIB.setAlphaPremultiplication False
                
                'If we are only resizing a single layer, make a copy of the layer's current offset.  We will use these
                ' to re-center the layer after it has been resized.
                origOffsetX = tmpLayerRef.getLayerOffsetX + (tmpLayerRef.layerDIB.getDIBWidth \ 2)
                origOffsetY = tmpLayerRef.getLayerOffsetY + (tmpLayerRef.layerDIB.getDIBHeight \ 2)
                
                'Null-pad the layer
                If thingToRotate = PD_AT_WHOLEIMAGE Then tmpLayerRef.convertToNullPaddedLayer pdImages(g_CurrentImage).Width, pdImages(g_CurrentImage).Height
                                
                'Give FreeImage a handle to the layer's pixel data
                fi_DIB = FreeImage_CreateFromDC(tmpLayerRef.layerDIB.getDIBDC)
            
                'There are two ways to rotate an image - enlarging the canvas to receive the fully rotated copy, or
                ' leaving the image the same size and truncating corners.  These require two different FreeImage functions.
                Select Case canvasResize
                
                    'Resize the canvas to accept the new image
                    Case 0
                        returnDIB = FreeImage_Rotate(fi_DIB, rotationAngle, RGB(255, 255, 255))
                        
                        nWidth = FreeImage_GetWidth(returnDIB)
                        nHeight = FreeImage_GetHeight(returnDIB)
                        
                    'Leave the canvas the same size
                    Case 1
                        returnDIB = FreeImage_RotateEx(fi_DIB, rotationAngle, 0, 0, cx, cy, True)
                        
                        nWidth = FreeImage_GetWidth(returnDIB)
                        nHeight = FreeImage_GetHeight(returnDIB)
                
                End Select
                
                'Resize the layer's DIB in preparation for the transfer
                tmpLayerRef.layerDIB.createBlank nWidth, nHeight, 32
                
                'Ask FreeImage to premultiply the image's alpha data
                FreeImage_PreMultiplyWithAlpha returnDIB
                
                'Copy the bits from the FreeImage DIB to our DIB
                SetDIBitsToDevice tmpLayerRef.layerDIB.getDIBDC, 0, 0, nWidth, nHeight, 0, 0, 0, nHeight, ByVal FreeImage_GetBits(returnDIB), ByVal FreeImage_GetInfo(returnDIB), 0&
                
                'With the transfer complete, release the FreeImage DIB and unload the library
                If returnDIB <> 0 Then FreeImage_UnloadEx returnDIB
                If fi_DIB <> 0 Then FreeImage_UnloadEx fi_DIB
                
                'If resizing the entire image, remove any null-padding now
                If thingToRotate = PD_AT_WHOLEIMAGE Then
                    tmpLayerRef.cropNullPaddedLayer
                
                'If resizing only a single layer, re-center it according to its old offset
                Else
                    tmpLayerRef.setLayerOffsetX origOffsetX - (tmpLayerRef.layerDIB.getDIBWidth \ 2)
                    tmpLayerRef.setLayerOffsetY origOffsetY - (tmpLayerRef.layerDIB.getDIBHeight \ 2)
                End If
                
                'Notify the parent of the change
                pdImages(g_CurrentImage).notifyImageChanged UNDO_LAYER, i
                
            'Continue with the next layer
            Next i
            
            'All layers have been rotated successfully!
            
            'Update the image's size
            If thingToRotate = PD_AT_WHOLEIMAGE Then
                pdImages(g_CurrentImage).updateSize False, nWidth, nHeight
                DisplaySize pdImages(g_CurrentImage)
            End If
            
            'Fit the new image on-screen and redraw its viewport
            Viewport_Engine.Stage1_InitializeBuffer pdImages(g_CurrentImage), FormMain.mainCanvas(0), "Image resize"
            
            Message "Rotation complete."
            SetProgBarVal 0
            releaseProgressBar
        
        End If
        
    Else
        Message "Arbitrary rotation requires the FreeImage plugin, which could not be located.  Rotation canceled."
        pdMsgBox "The FreeImage plugin is required for image rotation.  Please go to Tools -> Options -> Updates and allow PhotoDemon to download core plugins.  Then restart the program.", vbApplicationModal + vbOKOnly + vbInformation, "FreeImage plugin missing"
    End If
        
End Sub

'OK button
Private Sub cmdBar_OKClick()

    Select Case m_RotateTarget
    
        Case PD_AT_WHOLEIMAGE
            If optRotate(0) Then
                Process "Arbitrary image rotation", , buildParams(0, sltAngle, m_RotateTarget), UNDO_IMAGE
            Else
                Process "Arbitrary image rotation", , buildParams(1, sltAngle, m_RotateTarget), UNDO_IMAGE
            End If
        
        Case PD_AT_SINGLELAYER
            If optRotate(0) Then
                Process "Arbitrary layer rotation", , buildParams(0, sltAngle, m_RotateTarget), UNDO_LAYER
            Else
                Process "Arbitrary layer rotation", , buildParams(1, sltAngle, m_RotateTarget), UNDO_LAYER
            End If
    
    End Select
        
End Sub

Private Sub cmdBar_RequestPreviewUpdate()
    updatePreview
End Sub

Private Sub Form_Activate()
            
    'Set the dialog caption to match the current resize operation (resize image or resize single layer)
    Select Case m_RotateTarget
        
        Case PD_AT_WHOLEIMAGE
            Me.Caption = g_Language.TranslateMessage("Rotate image")
        
        Case PD_AT_SINGLELAYER
            Me.Caption = g_Language.TranslateMessage("Rotate layer")
        
    End Select
    
    'During the preview stage, we want to rotate a smaller version of the image or active layer.  This increases
    ' the speed of previewing immensely (especially for large images, like 10+ megapixel photos)
    Set smallDIB = New pdDIB
    
    'Determine a new image size that preserves the current aspect ratio
    Dim srcWidth As Long, srcHeight As Long
    Dim dWidth As Long, dHeight As Long
    
    Select Case m_RotateTarget
        
        Case PD_AT_WHOLEIMAGE
            srcWidth = pdImages(g_CurrentImage).Width
            srcHeight = pdImages(g_CurrentImage).Height
        
        Case PD_AT_SINGLELAYER
            srcWidth = pdImages(g_CurrentImage).getActiveLayer.layerDIB.getDIBWidth
            srcHeight = pdImages(g_CurrentImage).getActiveLayer.layerDIB.getDIBHeight
        
    End Select
    
    convertAspectRatio srcWidth, srcHeight, fxPreview.getPreviewWidth, fxPreview.getPreviewHeight, dWidth, dHeight
    
    'Create a new, smaller image at those dimensions
    If (dWidth < srcWidth) Or (dHeight < srcHeight) Then
        
        smallDIB.createBlank dWidth, dHeight, 32, 0
        
        Select Case m_RotateTarget
        
            Case PD_AT_WHOLEIMAGE
                pdImages(g_CurrentImage).getCompositedRect smallDIB, 0, 0, dWidth, dHeight, 0, 0, pdImages(g_CurrentImage).Width, pdImages(g_CurrentImage).Height, InterpolationModeHighQualityBicubic
            
            Case PD_AT_SINGLELAYER
                GDIPlusResizeDIB smallDIB, 0, 0, dWidth, dHeight, pdImages(g_CurrentImage).getActiveDIB, 0, 0, pdImages(g_CurrentImage).getActiveDIB.getDIBWidth, pdImages(g_CurrentImage).getActiveDIB.getDIBHeight, InterpolationModeHighQualityBicubic
            
        End Select
        
    'The source image or layer is tiny; just use the whole thing!
    Else
    
        Select Case m_RotateTarget
        
            Case PD_AT_WHOLEIMAGE
                pdImages(g_CurrentImage).getCompositedImage smallDIB
            
            Case PD_AT_SINGLELAYER
                smallDIB.createFromExistingDIB pdImages(g_CurrentImage).getActiveDIB
            
        End Select
        
    End If
        
    'Remove premultiplied alpha from the small DIB copy
    smallDIB.setAlphaPremultiplication False
    
    'Give the preview object a copy of this image data so it can show it to the user if requested
    fxPreview.setOriginalImage smallDIB
    
    'Assign the system hand cursor to all relevant objects
    Set m_Tooltip = New clsToolTip
    makeFormPretty Me, m_Tooltip
        
    'Render a preview
    cmdBar.markPreviewStatus True
    updatePreview
        
End Sub

Private Sub Form_Load()

    'Disable previewing until the dialog is fully initialized
    cmdBar.markPreviewStatus False
        
End Sub

Private Sub Form_Unload(Cancel As Integer)
    ReleaseFormTheming Me
End Sub

Private Sub OptRotate_Click(Index As Integer)
    updatePreview
End Sub

'Redraw the on-screen preview of the rotated image
Private Sub updatePreview()
    
    If cmdBar.previewsAllowed Then
        If optRotate(0).Value Then
            RotateArbitrary 0, sltAngle, m_RotateTarget, True
        Else
            RotateArbitrary 1, sltAngle, m_RotateTarget, True
        End If
    End If

End Sub

Private Sub sltAngle_Change()
    updatePreview
End Sub

'If the user changes the position and/or zoom of the preview viewport, the entire preview must be redrawn.
Private Sub fxPreview_ViewportChanged()
    updatePreview
End Sub

