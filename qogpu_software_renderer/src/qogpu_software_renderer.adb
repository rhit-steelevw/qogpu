with Ada.Text_IO; use Ada.Text_IO;
with Ada.Numerics; use Ada.Numerics; -- Provides Pi
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;


procedure qogpu_software_renderer is


   Screen_Width  : constant Integer := 600;
   Screen_Height : constant Integer := 480;


   subtype Color_Channel is Integer range 0 .. 255;

   type RGB_Color is record
      R : Color_Channel;
      G : Color_Channel;
      B : Color_Channel;
   end record;

   Black : constant RGB_Color := (R => 0, G => 0, B => 0);
   Red   : constant RGB_Color := (R => 255, G => 0, B => 0);
   Green : constant RGB_Color := (R => 0, G => 255, B => 0);
   Blue  : constant RGB_Color := (R => 0, G => 0, B => 255);
   White : constant RGB_Color := (R => 255, G => 255, B => 255);


   type Framebuffer is
     array (0 .. Screen_Height - 1, 0 .. Screen_Width - 1) of RGB_Color;

   Pixels : Framebuffer := (others => (others => White));

   type Depth_Array is
     array (0 .. Screen_Height - 1, 0 .. Screen_Width - 1) of Float;

   Depth : Depth_Array := (others => (others => Float'First));

   type Vertex is record
      X, Y, Z : Float;
      Xt, Yt, Texture_ID : Integer;
   end record;

   -- Each face contains three indices into the vertex array.
   type Face is array (1 .. 3) of Positive;

   -- Unconstrained array types: bounds are supplied when used.
   type Vertex_Array is array (Positive range <>) of Vertex;
   type Face_Array is array (Positive range <>) of Face;

   type Mesh (Vertex_Count, Face_Count : Positive) is record
      Vertices : Vertex_Array (1 .. Vertex_Count);
      Faces    : Face_Array (1 .. Face_Count);
   end record;

   type Texture_Array is
     array (Natural range <>, Natural range <>) of RGB_Color;
    
   Texture_Size : constant Positive := 16;

   subtype Square_Texture is Texture_Array
     (0 .. Texture_Size - 1, 0 .. Texture_Size - 1);

   type Six_Textures is array (1 .. 6) of Square_Texture;

   type Texture_Set is record
      Textures : Six_Textures;
   end record;

   
procedure Plot (X, Y : Integer; Color : RGB_Color) is
   begin
      if X in 0 .. Screen_Width - 1 and then Y in 0 .. Screen_Height - 1 then
         Pixels (Screen_Height -1 - Y, X) := Color;
      end if;
   end Plot;

function Signed_Triangle_Area
     (AX, AY, BX, BY, CX, CY : Integer) return Float
   is
   begin
      return 0.5 * Float
        ((BY - AY) * (BX + AX) +
         (CY - BY) * (CX + BX) +
         (AY - CY) * (AX + CX));
   end Signed_Triangle_Area;

procedure Draw_Triangle
     (A, B, C : Vertex; Texture : Texture_Array)
   is
      AX : Integer := Integer(A.X);
      AY : Integer := Integer(A.Y);
      BX : Integer := Integer(B.X);
      BY : Integer := Integer(B.Y);
      CX : Integer := Integer(C.X);
      CY : Integer := Integer(C.Y);

      BBMinX, BBMaxX, BBMinY, BBMaxY, TextureX, TextureY : Integer;
      ABC, Alpha, Beta, Gamma, Z : Float;
      Color : RGB_Color;
   begin
      
      BBMinX := Integer'Max
        (0, Integer'Min (AX, Integer'Min (BX, CX)));
      BBMaxX := Integer'Min
        (Screen_Width - 1, Integer'Max (AX, Integer'Max (BX, CX)));

      BBMinY := Integer'Max
        (0, Integer'Min (AY, Integer'Min (BY, CY)));
      BBMaxY := Integer'Min
        (Screen_Height - 1, Integer'Max (AY, Integer'Max (BY, CY)));

      ABC := Signed_Triangle_Area (AX, AY, BX, BY, CX, CY);

      if ABC = 0.0 then
         return;
      end if;

      for J in BBMinY .. BBMaxY loop
         for I in BBMinX .. BBMaxX loop
            Alpha :=
              Signed_Triangle_Area (I, J, BX, BY, CX, CY) / ABC;
            Beta :=
              Signed_Triangle_Area (I, J, CX, CY, AX, AY) / ABC;
            Gamma :=
              Signed_Triangle_Area (I, J, AX, AY, BX, BY) / ABC;

            if Alpha >= 0.0 and then
               Beta >= 0.0 and then
               Gamma >= 0.0
            then
               Z := Alpha * A.Z + Beta * B.Z + Gamma * C.Z;
               if Z > Depth(J,I) then 
                  TextureX := Integer(Alpha * Float(A.Xt) + Beta * Float(B.Xt) + Gamma * Float(C.Xt));
                  TextureY := Integer(Alpha * Float(A.Yt) + Beta * Float(B.Yt) + Gamma * Float(C.Yt));
                  Color := Texture(TextureY, TextureX);
                  Color.R := Integer(Float(Color.R) * Z/255.0);
                  Color.G := Integer(Float(Color.G) * Z/255.0);
                  Color.B := Integer(Float(Color.B) * Z/255.0);

                  Plot(I, J, Color);
                  Depth(J,I) := Z;
               end if;
            end if;
         end loop;
      end loop;
   end Draw_Triangle;

procedure Normalize_Mesh 
     (Model : in out Mesh)
   is
   scale_factor, Radius_Squared, X, Y, Z : float := 0.0;
   begin
      for I in Model.Vertices'Range loop
         X := Model.Vertices (I).X;
         Y := Model.Vertices (I).Y;
         Z := Model.Vertices (I).Z;
         Radius_Squared := X*X + Y*Y + Z*Z;
         if Radius_Squared > scale_factor then
            scale_factor := Radius_Squared;
         end if;
      end loop;
            scale_factor := Sqrt(scale_factor);
      if Scale_Factor = 0.0 then
         return;
      end if;
      for I in Model.Vertices'Range loop
         Model.Vertices (I).X := ((Model.Vertices (I).X)/scale_factor); 
         Model.Vertices (I).Y := ((Model.Vertices (I).Y)/Scale_Factor);
         Model.Vertices (I).Z := ((Model.Vertices (I).Z)/scale_factor);
      end loop;
   end Normalize_Mesh;

procedure Rotate_Vertex(Vert : in out Vertex; XAngle, YAngle, ZAngle : Float) is
   Cx : constant Float := Cos(XAngle);
   Sx : constant Float := Sin(XAngle);
   Cy : constant Float := Cos(YAngle);
   Sy : constant Float := Sin(YAngle);
   Cz : constant Float := Cos(ZAngle);
   Sz : constant Float := Sin(ZAngle);
   
   -- Temporary variables to hold coordinates during sequential steps
   X1, Y1, Z1 : Float;
   X2, Y2, Z2 : Float;
begin
   -- 1. Rotate around X-axis
   X1 := Vert.X;
   Y1 := Vert.Y * Cx - Vert.Z * Sx;
   Z1 := Vert.Y * Sx + Vert.Z * Cx;

   -- 2. Rotate around Y-axis
   X2 := X1 * Cy + Z1 * Sy;
   Y2 := Y1;
   Z2 := -X1 * Sy + Z1 * Cy;

   -- 3. Rotate around Z-axis
   Vert.X := X2 * Cz - Y2 * Sz;
   Vert.Y := X2 * Sz + Y2 * Cz;
   Vert.Z := Z2;
end Rotate_Vertex;

procedure Render_Face (Model : in Mesh; I : Integer; Texture : Texture_Set; XAngle, YAngle, ZAngle : Float) is
      A : Vertex := Model.Vertices (Model.Faces (I)(1));
      B : Vertex := Model.Vertices (Model.Faces (I)(2));
      C : Vertex := Model.Vertices (Model.Faces (I)(3));

      A_Screen : Vertex := A;
      B_Screen : Vertex := B;
      C_Screen : Vertex := C;

      Center_X : constant Float :=
        Float (Screen_Width - 1) / 2.0;
      Center_Y : constant Float :=
        Float (Screen_Height - 1) / 2.0;

      Screen_Scale : constant Float :=
        0.9 * Float (Integer'Min
          (Screen_Width - 1, Screen_Height - 1)) / 2.0;
   begin
      Rotate_Vertex (A, XAngle, YAngle, ZAngle);
      Rotate_Vertex (B, XAngle, YAngle, ZAngle);
      Rotate_Vertex (C, XAngle, YAngle, ZAngle);

      A_Screen.X := Center_X + A.X * Screen_Scale;
      A_Screen.Y := Center_Y + A.Y * Screen_Scale;
      A_Screen.Z := (A.Z + 1.0) * 0.5 * 255.0;

      B_Screen.X := Center_X + B.X * Screen_Scale;
      B_Screen.Y := Center_Y + B.Y * Screen_Scale;
      B_Screen.Z := (B.Z + 1.0) * 0.5 * 255.0;

      C_Screen.X := Center_X + C.X * Screen_Scale;
      C_Screen.Y := Center_Y + C.Y * Screen_Scale;
      C_Screen.Z := (C.Z + 1.0) * 0.5 * 255.0;

      Draw_Triangle (A_Screen, B_Screen, C_Screen, Texture.Textures (A.Texture_ID));
   end Render_Face;

procedure Render (Model : in Mesh; Texture : Texture_Set; XAngle, YAngle, ZAngle : Float) is
   begin
      for I in Model.Faces'Range loop            
            Render_Face (Model, I, Texture, XAngle, YAngle, ZAngle);
      end loop;
   end Render;

procedure Save_PPM (ID : Integer) is
      File : File_Type;
      Filename : constant String :=
        "frames/frame_" &
        Ada.Strings.Fixed.Trim (Integer'Image (ID), Ada.Strings.Both) &
        ".ppm";
   begin
      Create (File, Out_File, Filename);

      Put_Line (File, "P3");
      Put_Line
        (File, Integer'Image (Screen_Width) & Integer'Image (Screen_Height));
      Put_Line (File, "255");

      for Y in 0 .. Screen_Height - 1 loop
         for X in 0 .. Screen_Width - 1 loop
            Put_Line
              (File,
               Integer'Image (Pixels (Y, X).R) & " " &
               Integer'Image (Pixels (Y, X).G) & " " &
               Integer'Image (Pixels (Y, X).B));
         end loop;
      end loop;

      Close (File);
   end Save_PPM;

function Load_PPM (Filename : String) return Texture_Array is
      File : File_Type;

      -- Read one whitespace-separated item, skipping # comments.
      function Next_Token return String is
         Token       : Unbounded_String;
         Ch          : Character;
         At_Line_End : Boolean;
      begin
         while not End_Of_File (File) loop
            Look_Ahead (File, Ch, At_Line_End);

            if At_Line_End then
               Skip_Line (File);
               exit when Length (Token) > 0;

            elsif Ch = '#' then
               Skip_Line (File);
               exit when Length (Token) > 0;

            elsif Ch = ' ' or else
                  Ch = ASCII.HT or else
                  Ch = ASCII.CR
            then
               Get (File, Ch);
               exit when Length (Token) > 0;

            else
               Get (File, Ch);
               Append (Token, Ch);
            end if;
         end loop;

         if Length (Token) = 0 then
            raise End_Error with "Unexpected end of PPM file";
         end if;

         return To_String (Token);
      end Next_Token;

      function Read_Integer return Integer is
      begin
         return Integer'Value (Next_Token);
      end Read_Integer;

      Width, Height, Max_Value : Integer;
   begin
      Open (File, In_File, Filename);

      if Next_Token /= "P3" then
         raise Data_Error with "Expected an ASCII P3 PPM";
      end if;

      Width     := Read_Integer;
      Height    := Read_Integer;
      Max_Value := Read_Integer;

      if Width <= 0 or else Height <= 0 then
         raise Data_Error with "Invalid texture dimensions";
      end if;

      if Max_Value /= 255 then
         raise Data_Error with "Expected maximum channel value 255";
      end if;

      declare
         Texture : Texture_Array (0 .. Height - 1, 0 .. Width - 1);
         R, G, B : Integer;
      begin
         for Y in Texture'Range (1) loop
            for X in Texture'Range (2) loop
               R := Read_Integer;
               G := Read_Integer;
               B := Read_Integer;

               if R not in Color_Channel or else
                  G not in Color_Channel or else
                  B not in Color_Channel
               then
                  raise Data_Error with "RGB value outside 0 .. 255";
               end if;

               Texture (Y, X) := (R => R, G => G, B => B);
            end loop;
         end loop;

         Close (File);
         return Texture;
      end;

   exception
      when others =>
         if Is_Open (File) then
            Close (File);
         end if;
         raise;
   end Load_PPM;
  
  
  
      Cube : Mesh (Vertex_Count => 24, Face_Count => 12);
   Cube_Textures : Texture_Set;

   TEXTURE_SZ : constant Integer := Texture_Size;

begin
   Cube_Textures.Textures (1) := Load_PPM ("textures/front.ppm");
   Cube_Textures.Textures (2) := Load_PPM ("textures/left.ppm");
   Cube_Textures.Textures (3) := Load_PPM ("textures/bottom.ppm");
   Cube_Textures.Textures (4) := Load_PPM ("textures/right.ppm");
   Cube_Textures.Textures (5) := Load_PPM ("textures/top.ppm");
   Cube_Textures.Textures (6) := Load_PPM ("textures/back.ppm");
      Cube.Vertices :=
     (1 => (X => -1.0, Y =>  1.0, Z =>  1.0,
            Xt => 0, Yt => 0, Texture_ID => 1),
      2 => (X =>  1.0, Y =>  1.0, Z =>  1.0,
            Xt => 0, Yt => TEXTURE_SZ - 1, Texture_ID => 1),
      3 => (X =>  1.0, Y => -1.0, Z =>  1.0,
            Xt => TEXTURE_SZ - 1, Yt => TEXTURE_SZ - 1,
            Texture_ID => 1),
      4 => (X => -1.0, Y => -1.0, Z =>  1.0,
            Xt => TEXTURE_SZ - 1, Yt => 0, Texture_ID => 1),

      5 => (X => -1.0, Y =>  1.0, Z => -1.0,
            Xt => 0, Yt => 0, Texture_ID => 2),
      6 => (X => -1.0, Y =>  1.0, Z =>  1.0,
            Xt => 0, Yt => TEXTURE_SZ - 1, Texture_ID => 2),
      7 => (X => -1.0, Y => -1.0, Z =>  1.0,
            Xt => TEXTURE_SZ - 1, Yt => TEXTURE_SZ - 1,
            Texture_ID => 2),
      8 => (X => -1.0, Y => -1.0, Z => -1.0,
            Xt => TEXTURE_SZ - 1, Yt => 0, Texture_ID => 2),

      9 => (X => -1.0, Y => -1.0, Z =>  1.0,
            Xt => 0, Yt => 0, Texture_ID => 3),
     10 => (X =>  1.0, Y => -1.0, Z =>  1.0,
            Xt => 0, Yt => TEXTURE_SZ - 1, Texture_ID => 3),
     11 => (X =>  1.0, Y => -1.0, Z => -1.0,
            Xt => TEXTURE_SZ - 1, Yt => TEXTURE_SZ - 1,
            Texture_ID => 3),
     12 => (X => -1.0, Y => -1.0, Z => -1.0,
            Xt => TEXTURE_SZ - 1, Yt => 0, Texture_ID => 3),

     13 => (X => 1.0, Y =>  1.0, Z =>  1.0,
            Xt => 0, Yt => 0, Texture_ID => 4),
     14 => (X => 1.0, Y =>  1.0, Z => -1.0,
            Xt => 0, Yt => TEXTURE_SZ - 1, Texture_ID => 4),
     15 => (X => 1.0, Y => -1.0, Z => -1.0,
            Xt => TEXTURE_SZ - 1, Yt => TEXTURE_SZ - 1,
            Texture_ID => 4),
     16 => (X => 1.0, Y => -1.0, Z =>  1.0,
            Xt => TEXTURE_SZ - 1, Yt => 0, Texture_ID => 4),

     17 => (X => -1.0, Y => 1.0, Z => -1.0,
            Xt => 0, Yt => 0, Texture_ID => 5),
     18 => (X =>  1.0, Y => 1.0, Z => -1.0,
            Xt => 0, Yt => TEXTURE_SZ - 1, Texture_ID => 5),
     19 => (X =>  1.0, Y => 1.0, Z =>  1.0,
            Xt => TEXTURE_SZ - 1, Yt => TEXTURE_SZ - 1,
            Texture_ID => 5),
     20 => (X => -1.0, Y => 1.0, Z =>  1.0,
            Xt => TEXTURE_SZ - 1, Yt => 0, Texture_ID => 5),

     21 => (X => -1.0, Y => -1.0, Z => -1.0,
            Xt => 0, Yt => 0, Texture_ID => 6),
     22 => (X =>  1.0, Y => -1.0, Z => -1.0,
            Xt => 0, Yt => TEXTURE_SZ - 1, Texture_ID => 6),
     23 => (X =>  1.0, Y =>  1.0, Z => -1.0,
            Xt => TEXTURE_SZ - 1, Yt => TEXTURE_SZ - 1,
            Texture_ID => 6),
     24 => (X => -1.0, Y =>  1.0, Z => -1.0,
            Xt => TEXTURE_SZ - 1, Yt => 0, Texture_ID => 6));
   Cube.Faces :=
      (1 => (1, 2, 4),
       2 => (3, 4, 2),
       3 => (5, 6, 8),
       4 => (7, 8, 6),
       5 => (9, 10, 12),
       6 => (11, 12, 10),
       7 => (13, 14, 16),
       8 => (15, 16, 14),
       9 => (17, 18, 20),
      10 => (19, 20, 18),
      11 => (21, 22, 24),
      12 => (23, 24, 22));
      Normalize_Mesh(Cube);

      for I in 0 .. 119 loop
      Pixels := (others => (others => White));
      Depth  := (others => (others => Float'First));

      Render
        (Cube, Cube_Textures,
         Pi / 6.0,
         2.0 * Pi * Float (I) / 120.0,
         Pi/3.0);

      Save_PPM (I);
   end loop;
end qogpu_software_renderer;
