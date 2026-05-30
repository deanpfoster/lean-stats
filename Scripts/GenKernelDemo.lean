import LeanStats.Plot.Demo

def main : IO Unit := do
  IO.FS.writeFile "kernel_demo.html" LeanStats.Plot.kernelSmootherDemoHTML
  IO.println "Wrote kernel_demo.html"
