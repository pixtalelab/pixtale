using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.NetworkInformation;

// Launches the bundled Node server from this directory and opens the browser.

internal static class Program
{
    // Starts node.exe server.js on the first free port in 8082-8099.
    private static int Main()
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        Directory.SetCurrentDirectory(dir);

        int port = PickPort();
        if (port < 0)
        {
            Console.ReadKey(true);
            return 1;
        }

        string node = Path.Combine(dir, "node.exe");
        string server = Path.Combine(dir, "server.js");
        if (!File.Exists(node) || !File.Exists(server))
        {
            Console.ReadKey(true);
            return 1;
        }

        Environment.SetEnvironmentVariable("PORT", port.ToString());
        Environment.SetEnvironmentVariable("HOSTNAME", "0.0.0.0");
        Process.Start("http://localhost:" + port);

        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = node;
        psi.Arguments = "\"server.js\"";
        psi.WorkingDirectory = dir;
        psi.UseShellExecute = false;

        Process proc = Process.Start(psi);
        if (proc == null)
        {
            return 1;
        }
        proc.WaitForExit();
        return proc.ExitCode;
    }

    // Returns the first free TCP port from 8082 to 8099, or -1 if none are free.
    private static int PickPort()
    {
        for (int port = 8082; port <= 8099; port++)
        {
            if (!IsListening(port))
            {
                return port;
            }
        }
        return -1;
    }

    // Returns true when any process is already listening on the TCP port.
    private static bool IsListening(int port)
    {
        IPGlobalProperties props = IPGlobalProperties.GetIPGlobalProperties();
        IPEndPoint[] listeners = props.GetActiveTcpListeners();
        for (int i = 0; i < listeners.Length; i++)
        {
            if (listeners[i].Port == port)
            {
                return true;
            }
        }
        return false;
    }
}
