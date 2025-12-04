module teacher_rotation_tracker(
  input clk,
  input rst_n,
  input [1:0] cmd_type,
  input [2:0] week,
  input [1:0] K,
  input [1:0] teacher_id_in,
  input wr_en,
  output reg [1:0] class_out,
  output reg query_valid
);

  reg [1:0] initial_teacher_class [0:3];
  reg [2:0] rot_weeks [0:5];
  reg [1:0] rot_lists [0:5][0:3];
  reg [1:0] rot_sizes [0:5];
  
  reg [2:0] rotation_count;
  reg [2:0] rot_index;
  
  typedef enum {IDLE, CAPTURE} state_t;
  state_t state;
  
  reg [1:0] capture_count;
  reg [2:0] current_week;
  reg [1:0] current_K;
  reg [1:0] current_rot_list [0:3];
  
  reg [2:0] query_week_reg;
  reg [1:0] query_teacher_reg;
  reg query_active;
  reg [1:0] query_count;
  
  reg [1:0] computed_class;
  
  always_comb begin
    reg [1:0] temp_class [0:3];
    integer i, r;
    
    for (i = 0; i < 4; i++) temp_class[i] = initial_teacher_class[i];
    
    for (r = 0; r < 6; r++) begin
      if (r < rotation_count && rot_weeks[r] <= query_week_reg) begin
        automatic int sz = rot_sizes[r];
        if (sz > 1) begin
          automatic reg [1:0] last_class = temp_class[rot_lists[r][sz-1]];
          for (i = sz-1; i > 0; i--) begin
            temp_class[rot_lists[r][i]] = temp_class[rot_lists[r][i-1]];
          end
          temp_class[rot_lists[r][0]] = last_class;
        end
      end
    end
    computed_class = temp_class[query_teacher_reg];
  end
  
  always @(posedge clk or negedge rst_n) begin
    integer i;
    
    if (!rst_n) begin
      for (i = 0; i < 4; i++) initial_teacher_class[i] = i;
      for (i = 0; i < 6; i++) begin
        rot_weeks[i] = 3'b0;
        rot_sizes[i] = 2'b0;
        for (int j = 0; j < 4; j++) rot_lists[i][j] = 2'b0;
      end
      rotation_count <= 3'b0;
      rot_index <= 3'b0;
      state <= IDLE;
      capture_count <= 2'b0;
      query_active <= 1'b0;
      query_count <= 2'b0;
      class_out <= 2'b0;
      query_valid <= 1'b0;
    end else begin
      case(state)
        IDLE: begin
          if (wr_en) begin
            if (cmd_type == 0) begin
              current_week <= week;
              current_K <= K;
              capture_count <= 2'b0;
              state <= CAPTURE;
            end else if (cmd_type == 1) begin
              query_week_reg <= week;
              query_teacher_reg <= teacher_id_in;
              query_active <= 1'b1;
              query_count <= 2'b0;
            end
          end
        end
        
        CAPTURE: begin
          if (wr_en) begin
            current_rot_list[capture_count] <= teacher_id_in;
            if (capture_count == current_K - 1) begin
              if (rotation_count < 6) begin
                rot_weeks[rot_index] <= current_week;
                rot_sizes[rot_index] <= current_K;
                for (i = 0; i < 4; i++) begin
                  if (i < current_K) begin
                    rot_lists[rot_index][i] <= current_rot_list[i];
                  end else begin
                    rot_lists[rot_index][i] <= 2'b0;
                  end
                end
                rot_index <= (rot_index == 5) ? 3'b0 : (rot_index + 1);
                rotation_count <= rotation_count + 1;
              end
              state <= IDLE;
            end else begin
              capture_count <= capture_count + 1;
            end
          end
        end
      endcase
      
      if (query_active) begin
        query_count <= query_count + 1;
        if (query_count == 2) begin
          class_out <= computed_class;
          query_valid <= 1'b1;
        end
        if (query_count == 3) begin
          query_active <= 1'b0;
          query_valid <= 1'b0;
        end
      end
    end
  end
endmodule