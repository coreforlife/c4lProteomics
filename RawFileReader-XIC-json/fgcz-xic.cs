/// adapded from the ThermoFischer `Hello, world!` example provided by Jim Shofstahl 
/// see URL http://planetorbitrap.com/rawfilereader#.WjkqIUtJmL4
/// the ThermoFisher library has to be manual downloaded and installed
/// Please read the License document
/// Witold Wolski <wew@fgcz.ethz.ch> and Christian Panse <cp@fgcz.ethz.ch> and Christian Trachsel
/// 2017-09-25 Zurich, Switzerland
/// 2018-04-24 Zurich, Switzerland
/// 2018-06-04 San Diego, CA, USA added xic option
/// 2018-06-28 added xic and scan option
/// 2018-07-24 bugfix
/// 2018-11-23 added scanFilter option
/// 2019-01-28 extract monoisotopicmZ attribute; include segments in MGF iff no centroid data are availbale
/// 2019-05-28 save info as Yaml
/// 2019-10-08 data cleaning
 
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.ExceptionServices;
using System.Collections;

using System.Linq;
using ThermoFisher.CommonCore.Data;
using ThermoFisher.CommonCore.Data.Business;
using ThermoFisher.CommonCore.Data.FilterEnums;
using ThermoFisher.CommonCore.Data.Interfaces;
using ThermoFisher.CommonCore.MassPrecisionEstimator;
using ThermoFisher.CommonCore.RawFileReader;


namespace FGCZ_Raw
{
    internal static class Program
    {
        private static void Main(string[] args)
        {
            // This local variable controls if the AnalyzeAllScans method is called
            bool analyzeScans = false;
            string rawDiagVersion = "0.0.35";

            // Get the memory used at the beginning of processing
            Process processBefore = Process.GetCurrentProcess();
            
            long memoryBefore = processBefore.PrivateMemorySize64 / 1024;

            try
            {
                // Check to see if the RAW file name was supplied as an argument to the program
                string filename = string.Empty;
                string mode = string.Empty;
                Hashtable hashtable = new Hashtable()
                {
                    {"version", "print version information."},
                    {"info", "print the raw file's meta data."},
                    {"xic", "prints xic unfiltered."},
                };

                if (args.Length > 0)
                {
                    filename = args[0];

                    if (args.Length == 1)
                    {
                        Console.WriteLine("rawDiag version = {}", rawDiagVersion);
                        Console.WriteLine("missing mode argument. setting to mode = 'info'.");
                        mode = "info";
                    }
                    else
                    {
                        mode = args[1];
                    }


                    if (!hashtable.Contains(mode))
                    {
                        Console.WriteLine("rawDiag version = {}", rawDiagVersion);
                        Console.WriteLine("mode '{0}' not allowed. Please use one of the following modes:", mode);
                        foreach (var k in hashtable.Keys)
                        {
                            Console.WriteLine("{0} - {1}", k.ToString(), hashtable[k].ToString());
                        }

                        Environment.Exit(1);
                    }
                }

                if (string.IsNullOrEmpty(filename))
                {
                    
                    Console.WriteLine("No RAW file specified!");

                    return;
                }

                // Check to see if the specified RAW file exists
                if (!File.Exists(filename))
                {
                    Console.WriteLine("rawDiag version = {}", rawDiagVersion);
                    Console.WriteLine(@"The file doesn't exist in the specified location - " + filename);
                    
                    return;
                }

                // Create the IRawDataPlus object for accessing the RAW file
                var rawFile = RawFileReaderAdapter.FileFactory(filename);

                if (!rawFile.IsOpen || rawFile.IsError)
                {
                    Console.WriteLine("Unable to access the RAW file using the RawFileReader class!");

                    return;
                }

                // Check for any errors in the RAW file
                if (rawFile.IsError)
                {
                    Console.WriteLine("Error opening ({0}) - {1}", rawFile.FileError, filename);
                    
                    return;
                }

                // Check if the RAW file is being acquired
                if (rawFile.InAcquisition)
                {
                    Console.WriteLine("RAW file still being acquired - " + filename);

                    return;
                }

                if (mode == "info")
                {
                    // Get the number of instruments (controllers) present in the RAW file and set the 
                    // selected instrument to the MS instrument, first instance of it
                    Console.WriteLine("Number of instruments: {0}", rawFile.InstrumentCount);
                }

                rawFile.SelectInstrument(Device.MS, 1);
                //Console.WriteLine("DEBUG {0}", rawFile.GetInstrumentMethod(3).ToString());

                // Get the first and last scan from the RAW file
                int firstScanNumber = rawFile.RunHeaderEx.FirstSpectrum;
                int lastScanNumber = rawFile.RunHeaderEx.LastSpectrum;

                // Get the start and end time from the RAW file
                double startTime = rawFile.RunHeaderEx.StartTime;
                double endTime = rawFile.RunHeaderEx.EndTime;

                if (mode == "systeminfo")
                {

                    Console.WriteLine("raw file name: {0}", Path.GetFileName(filename));
                    // Print some OS and other information
                    Console.WriteLine("System Information:");
                    Console.WriteLine("    OS Version: " + Environment.OSVersion);
                    Console.WriteLine("    64 bit OS: " + Environment.Is64BitOperatingSystem);
                    Console.WriteLine("    Computer: " + Environment.MachineName);
                    Console.WriteLine("    number Cores: " + Environment.ProcessorCount);
                    Console.WriteLine("    Date: " + DateTime.Now);
                }

                if (mode == "info")
                {

                    // Get some information from the header portions of the RAW file and display that information.
                    // The information is general information pertaining to the RAW file.
                    Console.WriteLine("General File Information:");
                    Console.WriteLine("    RAW file: " + Path.GetFileName(rawFile.FileName));
                    Console.WriteLine("    RAW file version: " + rawFile.FileHeader.Revision);
                    Console.WriteLine("    Creation date: " + rawFile.FileHeader.CreationDate);
                    Console.WriteLine("    Operator: " + rawFile.FileHeader.WhoCreatedId);
                    Console.WriteLine("    Number of instruments: " + rawFile.InstrumentCount);
                    Console.WriteLine("    Description: " + rawFile.FileHeader.FileDescription);
                    Console.WriteLine("    Instrument model: " + rawFile.GetInstrumentData().Model);
                    Console.WriteLine("    Instrument name: " + rawFile.GetInstrumentData().Name);
//                    Console.WriteLine("   Instrument method: {0}", rawFile.GetAllInstrumentFriendlyNamesFromInstrumentMethod().Length);
                    Console.WriteLine("    Serial number: " + rawFile.GetInstrumentData().SerialNumber);
                    Console.WriteLine("    Software version: " + rawFile.GetInstrumentData().SoftwareVersion);
                    Console.WriteLine("    Firmware version: " + rawFile.GetInstrumentData().HardwareVersion);
                    Console.WriteLine("    Units: " + rawFile.GetInstrumentData().Units);
                    Console.WriteLine("    Mass resolution: {0:F3} ", rawFile.RunHeaderEx.MassResolution);
                    Console.WriteLine("    Number of scans: {0}", rawFile.RunHeaderEx.SpectraCount);
                    Console.WriteLine("    Number of ms2 scans: {0}",
                        Enumerable
                            .Range(1, lastScanNumber - firstScanNumber)
                            .Count(x => rawFile.GetFilterForScanNumber(x)
                                .ToString()
                                .Contains("Full ms2")));
                    Console.WriteLine("    Scan range: [{0}, {1}]", firstScanNumber, lastScanNumber);
                    Console.WriteLine("    Time range: [{0:F2}, {1:F2}]", startTime, endTime);
                    Console.WriteLine("    Mass range: [{0:F4}, {1:F4}]", rawFile.RunHeaderEx.LowMass,
                        rawFile.RunHeaderEx.HighMass);
                    Console.WriteLine();

                    // Get information related to the sample that was processed
                    Console.WriteLine("Sample Information:");
                    Console.WriteLine("    Sample name: " + rawFile.SampleInformation.SampleName);
                    Console.WriteLine("    Sample id: " + rawFile.SampleInformation.SampleId);
                    Console.WriteLine("    Sample type: " + rawFile.SampleInformation.SampleType);
                    Console.WriteLine("    Sample comment: " + rawFile.SampleInformation.Comment);
                    Console.WriteLine("    Sample vial: " + rawFile.SampleInformation.Vial);
                    Console.WriteLine("    Sample volume: " + rawFile.SampleInformation.SampleVolume);
                    Console.WriteLine("    Sample injection volume: " + rawFile.SampleInformation.InjectionVolume);
                    Console.WriteLine("    Sample row number: " + rawFile.SampleInformation.RowNumber);
                    Console.WriteLine("    Sample dilution factor: " + rawFile.SampleInformation.DilutionFactor);
                    Console.WriteLine();

                    // Read the first instrument method (most likely for the MS portion of the instrument).
                    // NOTE: This method reads the instrument methods from the RAW file but the underlying code
                    // uses some Microsoft code that hasn't been ported to Linux or MacOS.  Therefore this
                    // method won't work on those platforms therefore the check for Windows.
                    if (Environment.OSVersion.ToString().Contains("Windows"))
                    {
                        var deviceNames = rawFile.GetAllInstrumentNamesFromInstrumentMethod();

                        foreach (var device in deviceNames)
                        {
                            Console.WriteLine("Instrument method: " + device);
                        }

                        Console.WriteLine();
                    }
                }

                // Display all of the trailer extra data fields present in the RAW file

                // Get the number of filters present in the RAW file
                int numberFilters = rawFile.GetFilters().Count;

                // Get the scan filter for the first and last spectrum in the RAW file
                var firstFilter = rawFile.GetFilterForScanNumber(firstScanNumber);
                var lastFilter = rawFile.GetFilterForScanNumber(lastScanNumber);

                
                if (mode == "info")
                {
                    Console.WriteLine("Filter Information:");
                    Console.WriteLine("    Scan filter (first scan): " + firstFilter.ToString());
                    Console.WriteLine("    Scan filter (last scan): " + lastFilter.ToString());
                    Console.WriteLine("    Total number of filters: " + numberFilters);
                    Console.WriteLine();
                    //  ListTrailerExtraFields(rawFile);
                    Environment.Exit(0);
                }

                if (mode == "version")
                {
                     Console.WriteLine("version={}", rawDiagVersion);   
                     Environment.Exit(0);
                }
                

                if (mode == "xic")
                {
                    try   
                    {
                        var inputFilename = args[2];
                        double ppmError = Convert.ToDouble(args[3]);
                        var outputFilename = args[4];
                        List<double> massList = new List<double>();
                        if (File.Exists(args[2]))
                        {


                            foreach (var line in File.ReadAllLines(inputFilename))
                            {
                                massList.Add(Convert.ToDouble(line));
                            }

                            GetXIC(rawFile, -1, -1, massList, ppmError, outputFilename);
                        }

                        return;
                    }
                    catch (Exception ex)
                    {
                        Console.Error.WriteLine("failed to catch configfile and itol");
                        Console.Error.WriteLine("{}", ex.Message);
                        return;
                    }
                }

            }

            catch (Exception ex)
            {
                Console.WriteLine("Error accessing RAWFileReader library! - " + ex.Message);
            }

            // Get the memory used at the end of processing
            Process processAfter = Process.GetCurrentProcess();
            long memoryAfter = processAfter.PrivateMemorySize64 / 1024;

            Console.WriteLine();
            Console.WriteLine("Memory Usage:");
            Console.WriteLine("   Before {0} kb, After {1} kb, Extra {2} kb", memoryBefore, memoryAfter,
                memoryAfter - memoryBefore);
        }


        private static void GetXIC(IRawDataPlus rawFile, int startScan, int endScan, List<double> massList,
            double ppmError, string filename)
        {

            List<ChromatogramTraceSettings> settingList = new List<ChromatogramTraceSettings>();


            foreach (var mass in massList)
            {

                double massError = (0.5 * ppmError * mass) / 1000000;
                ChromatogramTraceSettings settings = new ChromatogramTraceSettings(TraceType.MassRange)
                {
                    Filter = "ms",
                    MassRanges = new[] {Range.Create(mass - massError, mass + massError)}
                };

                settingList.Add(settings);
            }

            IChromatogramSettings[] allSettings = settingList.ToArray();

            var data = rawFile.GetChromatogramData(allSettings, startScan, endScan);

            /// compose JSON string
            string json = "";
            List<string> L = new List<string>();

            // Split the data into the chromatograms
            var trace = ChromatogramSignal.FromChromatogramData(data);

            for (int i = 0; i < trace.Length; i++)
            {
                List<double> tTime = new List<double>();
                List<double> tIntensities = new List<double>();

                for (int j = 0; j < trace[i].Times.Count; j++)
                {
                    if (trace[i].Intensities[j] > 0)
                    {
                        tTime.Add(trace[i].Times[j]);
                        tIntensities.Add(trace[i].Intensities[j]);
                    }

                }
                //  file.WriteLine("\t{\n");

                json = string.Format("\t\"mass\": {0},\n", massList[i]) +
                       string.Format("\t\"rt\": [\n\t\t\t" + string.Join(",\n\t\t\t", tTime) + "\n\t\t],") +
                       string.Format("\n\t\"intensities\": [\n\t\t\t" + string.Join(",\n\t\t\t", tIntensities) + "\n\t\t]");

                L.Add("\t{\n" + json + "\n\t}");


            }

            using (System.IO.StreamWriter file =
                new System.IO.StreamWriter(filename))
            {
                file.WriteLine("[\n" + string.Join(",\n", L) + "\n]\n");
            }
        }
    }
}

