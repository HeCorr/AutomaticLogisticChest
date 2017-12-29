using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Reflection;
using AutomaticLogisticChest.Mod;
using System.IO;
using System.IO.Compression;
using System.Diagnostics;

namespace AutomaticLogisticChest
{
    class Program
    {
        static void Main(string[] args)
        {
            TemplateInfoJson info = new TemplateInfoJson();
            String infoJson = info.TransformText();
            System.IO.File.WriteAllText("Mod/info.json", infoJson);

            string fileName = String.Format("AutomaticLogisticChest_{0}.zip", System.Reflection.Assembly.GetExecutingAssembly().GetName().Version.ToString().Substring(2));
            string dest = string.Format(@"{0}\Factorio\mods", Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData));

            foreach (var file in new DirectoryInfo(dest).EnumerateFiles("AutomaticLogisticChest_*.*"))
            {
                file.Delete();
            }

            foreach (var directory in new DirectoryInfo(@"Mod\..").EnumerateDirectories("AutomaticLogisticChest_*"))
            {
                directory.Delete(true);
            }

            foreach (var file in new DirectoryInfo(@"Mod\..").EnumerateFiles("AutomaticLogisticChest_*.*"))
            {
                file.Delete();
            }

            Directory.Move("Mod", Path.GetFileNameWithoutExtension(fileName));

            ZipFile.CreateFromDirectory(Path.GetFileNameWithoutExtension(fileName), fileName, CompressionLevel.Optimal, true);



            string destFile = string.Format(@"{0}\{1}", dest, fileName);

            File.Copy(fileName, destFile);

            Process.Start(@"C:\Users\TillO\Desktop\Factorio.url");
        }
    }
}
