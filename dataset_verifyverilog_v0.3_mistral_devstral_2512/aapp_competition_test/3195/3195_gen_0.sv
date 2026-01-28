module traffic_light_probability (
    input clk,
    input rst_n,
    input start,
    
    // Configuration: light durations (8-bit, scaled to max 255)
    input [7:0] T_g,
    input [7:0] T_y,
    input [7:0] T_r,
    
    // Number of observations (max 8)
    input [3:0] num_obs,
    
    // Packed observations: each [23:0] = {time[15:0], color[1:0], unused[5:0]}
    // Color encoding: 0=green, 1=yellow, 2=red
    input [23:0] obs_0,
    input [23:0] obs_1,
    input [23:0] obs_2,
    input [23:0] obs_3,
    input [23:0] obs_4,
    input [23:0] obs_5,
    input [23:0] obs_6,
    input [23:0] obs_7,
    
    // Query: time and color
    input [15:0] query_time,
    input [1:0] query_color,
    
    // Result: probability in Q8.8 format (16-bit)
    output reg [15:0] probability,
    output reg done
);

// State machine states
reg [3:0] state;
localparam [3:0] IDLE = 4'd0;
localparam [3:0] COMPUTE_CYCLE = 4'd1;
localparam [3:0] PROCESS_OBS = 4'd2;
localparam [3:0] QUERY = 4'd3;
localparam [3:0] RESULT = 4'd4;

// Registers for computation
reg [15:0] total_cycle;  // T_g + T_y + T_r
reg [15:0] obs_time_reg;
reg [1:0] obs_color_reg;
reg [3:0] obs_counter;

// Query computation registers
reg [15:0] query_t_mod;

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        probability <= 16'd0;
        done <= 1'b0;
        obs_counter <= 4'd0;
        total_cycle <= 16'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= COMPUTE_CYCLE;
                    obs_counter <= 4'd0;
                end
            end
            
            COMPUTE_CYCLE: begin
                total_cycle <= T_g + T_y + T_r;
                state <= (num_obs > 0) ? PROCESS_OBS : QUERY;
            end
            
            PROCESS_OBS: begin
                // Extract current observation
                case (obs_counter)
                    4'd0: begin obs_time_reg <= obs_0[15:0]; obs_color_reg <= obs_0[17:16]; end
                    4'd1: begin obs_time_reg <= obs_1[15:0]; obs_color_reg <= obs_1[17:16]; end
                    4'd2: begin obs_time_reg <= obs_2[15:0]; obs_color_reg <= obs_2[17:16]; end
                    4'd3: begin obs_time_reg <= obs_3[15:0]; obs_color_reg <= obs_3[17:16]; end
                    4'd4: begin obs_time_reg <= obs_4[15:0]; obs_color_reg <= obs_4[17:16]; end
                    4'd5: begin obs_time_reg <= obs_5[15:0]; obs_color_reg <= obs_5[17:16]; end
                    4'd6: begin obs_time_reg <= obs_6[15:0]; obs_color_reg <= obs_6[17:16]; end
                    4'd7: begin obs_time_reg <= obs_7[15:0]; obs_color_reg <= obs_7[17:16]; end
                endcase
                
                obs_counter <= obs_counter + 1;
                if (obs_counter >= num_obs) begin
                    state <= QUERY;
                end
            end
            
            QUERY: begin
                // Compute query time modulo cycle
                query_t_mod <= query_time % total_cycle;
                state <= RESULT;
            end
            
            RESULT: begin
                // Compute probability based on query color
                case (query_color)
                    2'd0: probability <= (T_g << 8) / total_cycle;  // Green
                    2'd1: probability <= (T_y << 8) / total_cycle;  // Yellow
                    2'd2: probability <= (T_r << 8) / total_cycle;  // Red
                    default: probability <= 16'd0;
                endcase
                
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule