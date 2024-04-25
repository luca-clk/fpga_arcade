import obj_pkg::*;

module image_rendering (
  input wire                                vid_clk,
  input wire                                vid_reset,
  // video
  input logic                               active,
  input logic [11:0]                        active_h, // 1 clock latency between this and the vid_action_layer output
  input logic [11:0]                        active_v,
  // edges of the frame
  input logic [3:0][7:0]                    frame_widths, // if 0 no frame, bottom, top, right, left
  input logic [3:0][23:0]                   frame_color,
  // object position array
  input logic [obj_pkg::NUM_OBJ-1:0][11:0]  obj_x,
  input logic [obj_pkg::NUM_OBJ-1:0][11:0]  obj_y,
  input logic [obj_pkg::NUM_OBJ-1:0]        obj_en,
  input logic [obj_pkg::NUM_OBJ-1:0][23:0]  obj_color,

  // output video
  output logic [24:0]                       vid_action_layer    // R+G+B+T=transarency (msbit: 1 on, 0 off)
);

import vga_hd_pkg::*;

//relative ball position
logic [11:0]          obj_pos_rel_x;
logic [11:0]          obj_pos_rel_y;

// video generator:
always_ff @(posedge vid_clk) begin
  if (vid_reset) begin
    vid_action_layer <= 25'h0000000;
  end else if (active) begin
    // black
    vid_action_layer <= 25'h0000000;
    // put the object
    for (int obj_idx=0; obj_idx<obj_pkg::NUM_OBJ; obj_idx++) begin
      obj_pos_rel_x = active_h - obj_x[obj_idx];
      obj_pos_rel_y = active_v - obj_y[obj_idx];
      if (obj_en[obj_idx] &&
          obj_pos_rel_x >= 0 &&
          obj_pos_rel_y >= 0 &&
          obj_pos_rel_x < obj_pkg::ObjSizeX[obj_idx] &&
          obj_pos_rel_y < obj_pkg::ObjSizeY[obj_idx]) begin
        vid_action_layer <= {obj_pkg::Obj[obj_idx][obj_pos_rel_y][obj_pos_rel_x], obj_color[obj_idx]};
      end
    end
    // put the frame on top
    if (active_h < frame_widths[0]) begin
      vid_action_layer <= {1'b1, frame_color[0]}; // left
    end else if (active_h > vga_hd_pkg::ActivePels - frame_widths[1] - 1) begin
      vid_action_layer <= {1'b1, frame_color[1]}; // right
    end else if (active_v < frame_widths[2]) begin
      vid_action_layer <= {1'b1, frame_color[2]}; // top
    end else if (active_v > vga_hd_pkg::ActiveLines - frame_widths[3] - 1) begin
      vid_action_layer <= {1'b1, frame_color[3]}; // bottom
    end
  end else begin
    vid_action_layer <= 25'h0000000;
  end
end

endmodule
