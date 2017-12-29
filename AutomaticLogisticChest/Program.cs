using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Reflection;
using AutomaticLogisticChest.Mod;
using System.IO;
using System.IO.Compression;

namespace AutomaticLogisticChest
{
    class Program
    {
        static void Main(string[] args)
        {
            TemplateInfoJson info = new TemplateInfoJson();
            String infoJson = info.TransformText();
            System.IO.File.WriteAllText("Mod/info.json", infoJson);

            string fileName = String.Format("AutomaticLogisticChest_{0}.zip", System.Reflection.Assembly.GetExecutingAssembly().GetName().Version.ToString());

            foreach (var file in new DirectoryInfo("Mod/..").EnumerateFiles("*.zip"))
            {
                file.Delete();
            }
            
            ZipFile.CreateFromDirectory("Mod", fileName);

            string destFile = string.Format(@"{0}\Factorio\mods\{1}", Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), fileName);

            File.Copy(fileName, destFile);
        }
    }
}
