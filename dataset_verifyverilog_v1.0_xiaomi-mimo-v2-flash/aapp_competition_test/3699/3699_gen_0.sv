module Bottles (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] ax,
    input wire [15:0] ay,
    input wire [15:0] bx,
    input wire [15:0] by,
    input wire [15:0] bin_x,
    input wire [15:0] bin_y,
    input wire [15:0] bottle_x,
    input wire [15:0] bottle_y,
    input wire bottle_valid,
    input wire [3:0] bottle_index,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] RECV = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE = 2'd3;

    // Registers and Arrays
    reg [1:0] state;
    reg [1:0] next_state;
    reg [15:0] saved_ax, saved_ay, saved_bx, saved_by, saved_bin_x, saved_bin_y;
    
    // Storage for bottle data (16 entries)
    reg [31:0] bin_dist_sq [0:15]; // 32-bit for accumulation
    reg [31:0] adil_dist_sq [0:15];
    reg [31:0] bera_dist_sq [0:15];
    reg [31:0] savings_adil [0:15];
    reg [31:0] savings_bera [0:15];
    
    // Computation registers
    reg [31:0] total_base;
    reg [31:0] max_single;
    reg [31:0] max_dual;
    reg [31:0] current_sum;
    reg [3:0] compute_idx;
    
    // Top 2 tracking for Adil and Bera
    reg [31:0] top1_adil_val, top2_adil_val;
    reg [3:0] top1_adil_idx, top2_adil_idx;
    reg [31:0] top1_bera_val, top2_bera_val;
    reg [3:0] top1_bera_idx, top2_bera_idx;
    
    // Temp calculations
    wire signed [31:0] dx_bin, dy_bin;
    wire signed [31:0] dx_adil, dy_adil;
    wire signed [31:0] dx_bera, dy_bera;
    wire [31:0] temp_bin_sq;
    wire [31:0] temp_adil_sq;
    wire [31:0] temp_bera_sq;
    wire [31:0] temp_savings_adil;
    wire [31:0] temp_savings_bera;
    
    // Intermediate wire assignments for squaring
    assign dx_bin = saved_bin_x - bottle_x;
    assign dy_bin = saved_bin_y - bottle_y;
    assign dx_adil = saved_ax - bottle_x;
    assign dy_adil = saved_ay - bottle_y;
    assign dx_bera = saved_bx - bottle_x;
    assign dy_bera = saved_by - bottle_y;
    
    // Squaring logic (using 16x16 -> 32 bit product)
    assign temp_bin_sq = (dx_bin * dx_bin) + (dy_bin * dy_bin);
    assign temp_adil_sq = (dx_adil * dx_adil) + (dy_adil * dy_adil);
    assign temp_bera_sq = (dx_bera * dx_bera) + (dy_bera * dy_bera);
    
    // Savings: 2 * bin_dist - person_dist
    assign temp_savings_adil = {1'b0, temp_bin_sq} + {1'b0, temp_bin_sq} - temp_adil_sq;
    assign temp_savings_bera = {1'b0, temp_bin_sq} + {1'b0, temp_bin_sq} - temp_bera_sq;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b0;
            done <= 1'b0;
            result <= 32'd0;
            current_sum <= 32'd0;
            compute_idx <= 4'd0;
            total_base <= 32'd0;
            max_single <= 32'd0;
            max_dual <= 32'd0;
            top1_adil_val <= 32'd0;
            top2_adil_val <= 32'd0;
            top1_adil_idx <= 4'd0;
            top2_adil_idx <= 4'd0;
            top1_bera_val <= 32'd0;
            top2_bera_val <= 32'd0;
            top1_bera_idx <= 4'd0;
            top2_bera_idx <= 4'd0;
            saved_ax <= 16'd0;
            saved_ay <= 16'd0;
            saved_bx <= 16'd0;
            saved_by <= 16'd0;
            saved_bin_x <= 16'd0;
            saved_bin_y <= 16'd0;
            // Initialize arrays (required for Icarus)
            bin_dist_sq[0] <= 32'd0; bin_dist_sq[1] <= 32'd0; bin_dist_sq[2] <= 32'd0; bin_dist_sq[3] <= 32'd0;
            bin_dist_sq[4] <= 32'd0; bin_dist_sq[5] <= 32'd0; bin_dist_sq[6] <= 32'd0; bin_dist_sq[7] <= 32'd0;
            bin_dist_sq[8] <= 32'd0; bin_dist_sq[9] <= 32'd0; bin_dist_sq[10] <= 32'd0; bin_dist_sq[11] <= 32'd0;
            bin_dist_sq[12] <= 32'd0; bin_dist_sq[13] <= 32'd0; bin_dist_sq[14] <= 32'd0; bin_dist_sq[15] <= 32'd0;
            adil_dist_sq[0] <= 32'd0; adil_dist_sq[1] <= 32'd0; adil_dist_sq[2] <= 32'd0; adil_dist_sq[3] <= 32'd0;
            adil_dist_sq[4] <= 32'd0; adil_dist_sq[5] <= 32'd0; adil_dist_sq[6] <= 32'd0; adil_dist_sq[7] <= 32'd0;
            adil_dist_sq[8] <= 32'd0; adil_dist_sq[9] <= 32'd0; adil_dist_sq[10] <= 32'd0; adil_dist_sq[11] <= 32'd0;
            adil_dist_sq[12] <= 32'd0; adil_dist_sq[13] <= 32'd0; adil_dist_sq[14] <= 32'd0; adil_dist_sq[15] <= 32'd0;
            bera_dist_sq[0] <= 32'd0; bera_dist_sq[1] <= 32'd0; bera_dist_sq[2] <= 32'd0; bera_dist_sq[3] <= 32'd0;
            bera_dist_sq[4] <= 32'd0; bera_dist_sq[5] <= 32'd0; bera_dist_sq[6] <= 32'd0; bera_dist_sq[7] <= 32'd0;
            bera_dist_sq[8] <= 32'd0; bera_dist_sq[9] <= 32'd0; bera_dist_sq[10] <= 32'd0; bera_dist_sq[11] <= 32'd0;
            bera_dist_sq[12] <= 32'd0; bera_dist_sq[13] <= 32'd0; bera_dist_sq[14] <= 32'd0; bera_dist_sq[15] <= 32'd0;
            savings_adil[0] <= 32'd0; savings_adil[1] <= 32'd0; savings_adil[2] <= 32'd0; savings_adil[3] <= 32'd0;
            savings_adil[4] <= 32'd0; savings_adil[5] <= 32'd0; savings_adil[6] <= 32'd0; savings_adil[7] <= 32'd0;
            savings_adil[8] <= 32'd0; savings_adil[9] <= 32'd0; savings_adil[10] <= 32'd0; savings_adil[11] <= 32'd0;
            savings_adil[12] <= 32'd0; savings_adil[13] <= 32'd0; savings_adil[14] <= 32'd0; savings_adil[15] <= 32'd0;
            savings_bera[0] <= 32'd0; savings_bera[1] <= 32'd0; savings_bera[2] <= 32'd0; savings_bera[3] <= 32'd0;
            savings_bera[4] <= 32'd0; savings_bera[5] <= 32'd0; savings_bera[6] <= 32'd0; savings_bera[7] <= 32'd0;
            savings_bera[8] <= 32'd0; savings_bera[9] <= 32'd0; savings_bera[10] <= 32'd0; savings_bera[11] <= 32'd0;
            savings_bera[12] <= 32'd0; savings_bera[13] <= 32'd0; savings_bera[14] <= 32'd0; savings_bera[15] <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    if (start) begin
                        state <= RECV;
                        // Capture static coordinates
                        saved_ax <= ax;
                        saved_ay <= ay;
                        saved_bx <= bx;
                        saved_by <= by;
                        saved_bin_x <= bin_x;
                        saved_bin_y <= bin_y;
                    end
                end
                
                RECV: begin
                    // Store incoming bottle data when valid
                    if (bottle_valid) begin
                        bin_dist_sq[bottle_index] <= temp_bin_sq;
                        adil_dist_sq[bottle_index] <= temp_adil_sq;
                        bera_dist_sq[bottle_index] <= temp_bera_sq;
                        savings_adil[bottle_index] <= temp_savings_adil;
                        savings_bera[bottle_index] <= temp_savings_bera;
                        // Check if we have received all bottles (assume index 15 is last)
                        if (bottle_index == 4'd15) begin
                            ready <= 1'b0; // Stop accepting input
                            current_sum <= 32'd0;
                            compute_idx <= 4'd0;
                            total_base <= 32'd0;
                            // Reset top trackers
                            top1_adil_val <= 32'd0; top2_adil_val <= 32'd0;
                            top1_adil_idx <= 4'd0; top2_adil_idx <= 4'd0;
                            top1_bera_val <= 32'd0; top2_bera_val <= 32'd0;
                            top1_bera_idx <= 4'd0; top2_bera_idx <= 4'd0;
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Loop through all 16 bottles
                    if (compute_idx < 4'd16) begin
                        // Accumulate total_base
                        total_base <= total_base + bin_dist_sq[compute_idx];
                        
                        // Update top 2 Adil
                        if (savings_adil[compute_idx] > top1_adil_val) begin
                            top2_adil_val <= top1_adil_val;
                            top2_adil_idx <= top1_adil_idx;
                            top1_adil_val <= savings_adil[compute_idx];
                            top1_adil_idx <= compute_idx;
                        end else if (savings_adil[compute_idx] > top2_adil_val) begin
                            top2_adil_val <= savings_adil[compute_idx];
                            top2_adil_idx <= compute_idx;
                        end
                        
                        // Update top 2 Bera
                        if (savings_bera[compute_idx] > top1_bera_val) begin
                            top2_bera_val <= top1_bera_val;
                            top2_bera_idx <= top1_bera_idx;
                            top1_bera_val <= savings_bera[compute_idx];
                            top1_bera_idx <= compute_idx;
                        end else if (savings_bera[compute_idx] > top2_bera_val) begin
                            top2_bera_val <= savings_bera[compute_idx];
                            top2_bera_idx <= compute_idx;
                        end
                        
                        compute_idx <= compute_idx + 4'd1;
                    end else begin
                        // All bottles processed, calculate final result
                        total_base <= {1'b0, total_base} + {1'b0, total_base}; // Multiply by 2
                        
                        // Max Single
                        if (top1_adil_val > top1_bera_val)
                            max_single <= top1_adil_val;
                        else
                            max_single <= top1_bera_val;
                        
                        // Max Dual
                        if (top1_adil_idx != top1_bera_idx) begin
                            max_dual <= top1_adil_val + top1_bera_val;
                        end else begin
                            // Conflict: check combinations
                            if ((top1_adil_val + top2_bera_val) > (top2_adil_val + top1_bera_val))
                                max_dual <= top1_adil_val + top2_bera_val;
                            else
                                max_dual <= top2_adil_val + top1_bera_val;
                        end
                        
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    if (max_single > max_dual)
                        result <= total_base - max_single;
                    else
                        result <= total_base - max_dual;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule