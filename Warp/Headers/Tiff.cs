﻿using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using BitMiracle.LibTiff.Classic;
using Warp.Tools;

/*
LICENSE NOTE FOR TIFF LIBRARY:

LibTiff.Net
Copyright (c) 2008-2011, Bit Miracle

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this list 
of conditions and the following disclaimer.

Redistributions in binary form must reproduce the above copyright notice, this 
list of conditions and the following disclaimer in the documentation and/or 
other materials provided with the distribution.

Neither the name of the Bit Miracle nor the names of its contributors may be used 
to endorse or promote products derived from this software without specific prior 
written permission.
*/

namespace Warp.Headers
{
    public enum TiffDataType
    {
        Byte = 0,
        Ushort = 1,
        Short = 2,
        Uint = 3,
        Int = 4,
        Ulong = 5,
        Long = 6,
        Float = 7,
        Double = 8
    }

    public class HeaderTiff : MapHeader
    {
        private string Path;
        public TiffDataType Mode = TiffDataType.Float;

        public HeaderTiff()
        {
        }

        public HeaderTiff(string path)
        {
            Path = path;

            using (Tiff Image = Tiff.Open(path, "r"))
            {
                {
                    FieldValue[] value = Image.GetField(TiffTag.IMAGEWIDTH);
                    Dimensions.X = value[0].ToInt();
                }
                {
                    FieldValue[] value = Image.GetField(TiffTag.IMAGELENGTH);
                    Dimensions.Y = value[0].ToInt();
                }
                {
                    Dimensions.Z = Image.NumberOfDirectories();
                }
                {
                    FieldValue[] value = Image.GetField(TiffTag.SAMPLEFORMAT);
                    SampleFormat Format = SampleFormat.UINT;// (SampleFormat)value[0].ToInt();

                    int BitsPerPixel = 8;// Image.GetField(TiffTag.BITSPERSAMPLE)[0].ToInt();

                    if (Format == SampleFormat.UINT)
                    {
                        if (BitsPerPixel == 8)
                            Mode = TiffDataType.Byte;
                        else if (BitsPerPixel == 16)
                            Mode = TiffDataType.Ushort;
                        else if (BitsPerPixel == 32)
                            Mode = TiffDataType.Uint;
                        else if (BitsPerPixel == 64)
                            Mode = TiffDataType.Ulong;
                        else
                            throw new FormatException("Unexpected bits per pixel.");
                    }
                    else if (Format == SampleFormat.INT)
                    {
                        if (BitsPerPixel == 16)
                            Mode = TiffDataType.Short;
                        else if (BitsPerPixel == 32)
                            Mode = TiffDataType.Int;
                        else if (BitsPerPixel == 64)
                            Mode = TiffDataType.Long;
                        else
                            throw new FormatException("Unexpected bits per pixel.");
                    }
                    else if (Format == SampleFormat.IEEEFP)
                    {
                        if (BitsPerPixel == 32)
                            Mode = TiffDataType.Float;
                        else if (BitsPerPixel == 64)
                            Mode = TiffDataType.Double;
                        else
                            throw new FormatException("Unexpected bits per pixel.");
                    }
                }
            }
        }

        public override void Write(BinaryWriter writer)
        {
            throw  new NotImplementedException();
        }

        public float[][] ReadData(int layer = -1)
        {
            float[][] Slices = new float[layer < 0 ? Dimensions.Z : 1][];

            for (int slice = 0; slice < Slices.Length; slice++)
            {
                using (Tiff Image = Tiff.Open(Path, "r"))
                {
                    bool Encoded = false;
                    FieldValue[] compressionTagValue = Image.GetField(TiffTag.COMPRESSION);
                    if (compressionTagValue != null)
                        Encoded = (compressionTagValue[0].ToInt() != (int)Compression.NONE);

                    int NumberOfStrips = Image.NumberOfStrips();

                    float[] ConvertedData = new float[Dimensions.ElementsSlice()];

                    Image.SetDirectory(layer < 0 ? (short)slice : (short)layer);

                    int Offset = 0;
                    byte[] StripsData = new byte[NumberOfStrips * Image.StripSize()];
                    for (int i = 0; i < NumberOfStrips; i++)
                    {
                        int bytesRead = readStrip(Image, i, StripsData, Offset, Encoded);
                        Offset += bytesRead;
                    }

                    unsafe
                    {
                        fixed (byte* StripsDataPtr = StripsData)
                        fixed (float* ConvertedDataPtr = ConvertedData)
                        {
                            if (Mode == TiffDataType.Byte)
                            {
                                byte* StripsDataP = (byte*)StripsDataPtr;
                                for (int i = 0; i < ConvertedData.Length; i++)
                                    ConvertedDataPtr[i] = (float)StripsDataP[i];
                            }
                            else if (Mode == TiffDataType.Ushort)
                            {
                                ushort* StripsDataP = (ushort*)StripsDataPtr;
                                for (int i = 0; i < ConvertedData.Length; i++)
                                    ConvertedDataPtr[i] = (float)StripsDataP[i];
                            }
                            else if (Mode == TiffDataType.Short)
                            {
                                short* StripsDataP = (short*)StripsDataPtr;
                                for (int i = 0; i < ConvertedData.Length; i++)
                                    ConvertedDataPtr[i] = (float)StripsDataP[i];
                            }
                            else if (Mode == TiffDataType.Uint)
                            {
                                uint* StripsDataP = (uint*)StripsDataPtr;
                                for (int i = 0; i < ConvertedData.Length; i++)
                                    ConvertedDataPtr[i] = (float)StripsDataP[i];
                            }
                            else if (Mode == TiffDataType.Int)
                            {
                                int* StripsDataP = (int*)StripsDataPtr;
                                for (int i = 0; i < ConvertedData.Length; i++)
                                    ConvertedDataPtr[i] = (float)StripsDataP[i];
                            }
                            else if (Mode == TiffDataType.Ulong)
                            {
                                ulong* StripsDataP = (ulong*)StripsDataPtr;
                                for (int i = 0; i < ConvertedData.Length; i++)
                                    ConvertedDataPtr[i] = (float)StripsDataP[i];
                            }
                            else if (Mode == TiffDataType.Long)
                            {
                                long* StripsDataP = (long*)StripsDataPtr;
                                for (int i = 0; i < ConvertedData.Length; i++)
                                    ConvertedDataPtr[i] = (float)StripsDataP[i];
                            }
                            else if (Mode == TiffDataType.Float)
                            {
                                float* StripsDataP = (float*)StripsDataPtr;
                                for (int i = 0; i < ConvertedData.Length; i++)
                                    ConvertedDataPtr[i] = StripsDataP[i];
                            }
                            else if (Mode == TiffDataType.Double)
                            {
                                double* StripsDataP = (double*)StripsDataPtr;
                                for (int i = 0; i < ConvertedData.Length; i++)
                                    ConvertedDataPtr[i] = (float)StripsDataP[i];
                            }
                        }
                    }

                    Slices[slice] = ConvertedData;
                }
            }

            return Slices;
        }

        private static int readStrip(Tiff image, int stripNumber, byte[] buffer, int offset, bool encoded)
        {
            if (encoded)
                return image.ReadEncodedStrip(stripNumber, buffer, offset, buffer.Length - offset);
            else
                return image.ReadRawStrip(stripNumber, buffer, offset, buffer.Length - offset);
        }

        public override Type GetValueType()
        {
            switch (Mode)
            {
                case TiffDataType.Byte:
                    return typeof(byte);
                case TiffDataType.Ushort:
                    return typeof(ushort);
                case TiffDataType.Short:
                    return typeof(short);
                case TiffDataType.Uint:
                    return typeof(uint);
                case TiffDataType.Int:
                    return typeof(int);
                case TiffDataType.Ulong:
                    return typeof(ulong);
                case TiffDataType.Long:
                    return typeof(long);
                case TiffDataType.Float:
                    return typeof(float);
                case TiffDataType.Double:
                    return typeof(double);
            }

            throw new Exception("Unknown data type.");
        }

        public override void SetValueType(Type t)
        {
            throw new NotImplementedException();
        }
    }
}
