package main

import (
	"image/color"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

// SlimProgressBar is a custom progress bar with reduced height
type SlimProgressBar struct {
	widget.ProgressBar
	height float32
}

func NewSlimProgressBar(height float32) *SlimProgressBar {
	bar := &SlimProgressBar{
		height: height,
	}
	bar.ExtendBaseWidget(bar)
	return bar
}

func (s *SlimProgressBar) CreateRenderer() fyne.WidgetRenderer {
	s.ExtendBaseWidget(s)
	v := fyne.CurrentApp().Settings().ThemeVariant()
	spbr := &slimProgressBarRenderer{
		bar:        s,
		progress:   canvas.NewRectangle(color.NRGBA{}),
		background: canvas.NewRectangle(color.NRGBA{}),
	}
	th := spbr.bar.Theme()
	spbr.progress.FillColor = th.Color(theme.ColorNamePrimary, v)

	return spbr
}

type slimProgressBarRenderer struct {
	bar        *SlimProgressBar
	progress   *canvas.Rectangle
	background *canvas.Rectangle
	ratio      float32
}

func (s *slimProgressBarRenderer) calculateRatio() {
	if s.bar.Value < s.bar.Min {
		s.bar.Value = s.bar.Min
	}
	if s.bar.Value > s.bar.Max {
		s.bar.Value = s.bar.Max
	}

	delta := s.bar.Max - s.bar.Min
	s.ratio = float32((s.bar.Value - s.bar.Min) / delta)
}

func (r *slimProgressBarRenderer) MinSize() fyne.Size {
	return fyne.NewSize(100, r.bar.height)
}

func (r *slimProgressBarRenderer) Layout(size fyne.Size) {
	r.calculateRatio()
	r.background.Resize(size)
	r.background.Move(fyne.NewPos(0, 0))

	progressWidth := int(float64(size.Width) * float64(r.ratio))
	r.progress.Resize(fyne.NewSize(float32(progressWidth), size.Height))
	r.progress.Move(fyne.NewPos(0, 0))
}

func (r *slimProgressBarRenderer) Refresh() {
	r.Layout(r.bar.Size())
	fyne.Do(func() {
		canvas.Refresh(r.progress)
	})
}

func (r *slimProgressBarRenderer) Objects() []fyne.CanvasObject {
	return []fyne.CanvasObject{r.background, r.progress}
}

func (r *slimProgressBarRenderer) Destroy() {}
