module fog_miss_counter(
  input clk,
  input rst_n,
  input start,
  input [1:0] num_origins,
  input [1:0] m_i [0:3],
  input [15:0] d_i [0:3],
  input signed [15:0] l_i [0:3],
  input signed [15:0] r_i [0:3],
  input [15:0] h_i [0:3],
  input [15:0] delta_d_i [0:3],
  input signed [15:0] delta_x_i [0:3],
  input signed [15:0] delta_h_i [0:3],
  output reg [5:0] missed_count,
  output reg done
);

  typedef enum logic [1:0] {IDLE, INIT, PROCESS, DONE} state_t;
  
  typedef struct packed {
    logic valid;
    logic [15:0] day;
    logic signed [15:0] l;
    logic signed [15:0] r;
    logic [15:0] h;
  } fog_struct;
  
  typedef struct packed {
    logic signed [15:0] l;
    logic signed [15:0] r;
    logic [15:0] h;
  } net_struct;

  // Internal registers
  state_t state;
  fog_struct fog_array [0:11];
  net_struct nets [0:15];
  reg [3:0] net_count;
  reg [3:0] total_fogs;
  reg [1:0] num_origins_reg;
  reg [1:0] m_i_reg [0:3];
  reg [15:0] d_i_reg [0:3];
  reg signed [15:0] l_i_reg [0:3];
  reg signed [15:0] r_i_reg [0:3];
  reg [15:0] h_i_reg [0:3];
  reg [15:0] delta_d_i_reg [0:3];
  reg signed [15:0] delta_x_i_reg [0:3];
  reg signed [15:0] delta_h_i_reg [0:3];
  reg [5:0] missed_count_reg;
  
  // Processing signals
  integer min_index;
  logic [15:0] min_day;
  logic contained;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      foreach (fog_array[i]) fog_array[i].valid <= 1'b0;
      net_count <= 0;
      total_fogs <= 0;
      done <= 1'b0;
      missed_count_reg <= 0;
      missed_count <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          missed_count <= 0;
          if (start) begin
            num_origins_reg <= num_origins;
            foreach (m_i_reg[i]) m_i_reg[i] <= m_i[i];
            foreach (d_i_reg[i]) d_i_reg[i] <= d_i[i];
            foreach (l_i_reg[i]) l_i_reg[i] <= l_i[i];
            foreach (r_i_reg[i]) r_i_reg[i] <= r_i[i];
            foreach (h_i_reg[i]) h_i_reg[i] <= h_i[i];
            foreach (delta_d_i_reg[i]) delta_d_i_reg[i] <= delta_d_i[i];
            foreach (delta_x_i_reg[i]) delta_x_i_reg[i] <= delta_x_i[i];
            foreach (delta_h_i_reg[i]) delta_h_i_reg[i] <= delta_h_i[i];
            state <= INIT;
          end
        end
        
        INIT: begin
          foreach (fog_array[i]) fog_array[i].valid <= 1'b0;
          missed_count_reg <= 0;
          net_count <= 0;
          total_fogs <= 0;
          
          // Generate fogs for all origins
          begin
            integer fog_index = 0;
            for (int i=0; i<4; i++) begin
              if (i < num_origins_reg) begin
                automatic int m_val = m_i_reg[i];
                for (int j=0; j<m_val; j++) begin
                  if (fog_index < 12) begin
                    fog_array[fog_index].valid <= 1'b1;
                    fog_array[fog_index].day <= d_i_reg[i] + (j * delta_d_i_reg[i]);
                    fog_array[fog_index].l <= l_i_reg[i] + (j * delta_x_i_reg[i]);
                    fog_array[fog_index].r <= r_i_reg[i] + (j * delta_x_i_reg[i]);
                    fog_array[fog_index].h <= h_i_reg[i] + (j * delta_h_i_reg[i]);
                    total_fogs <= fog_index + 1;
                    fog_index++;
                  end
                end
              end
            end
          end
          state <= PROCESS;
        end
        
        PROCESS: begin
          // Find min-day valid fog
          min_index = -1;
          min_day = 16'hFFFF;
          for (int k=0; k<12; k++) begin
            if (fog_array[k].valid && (fog_array[k].day < min_day || min_index == -1)) begin
              min_day = fog_array[k].day;
              min_index = k;
            end
          end
          
          if (min_index != -1) begin
            // Check containment
            contained = 1'b0;
            for (int n=0; n<16; n++) begin
              if (n < net_count) begin
                if (nets[n].l <= fog_array[min_index].l && 
                    nets[n].r >= fog_array[min_index].r && 
                    nets[n].h >= fog_array[min_index].h) begin
                  contained = 1'b1;
                end
              end
            end
            
            if (!contained) begin
              missed_count_reg <= missed_count_reg + 1;
              if (net_count < 16) begin
                nets[net_count].l <= fog_array[min_index].l;
                nets[net_count].r <= fog_array[min_index].r;
                nets[net_count].h <= fog_array[min_index].h;
                net_count <= net_count + 1;
              end
            end
            
            fog_array[min_index].valid <= 1'b0;
          end
          else begin
            state <= DONE;
            missed_count <= missed_count_reg;
          end
        end
        
        DONE: begin
          done <= 1'b1;
          if (start) state <= IDLE; // Optional: Auto-reset on new start
        end
      endcase
    end
  end
endmodule