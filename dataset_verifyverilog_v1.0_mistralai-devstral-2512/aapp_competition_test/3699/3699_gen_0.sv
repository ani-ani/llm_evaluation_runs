module BottleRecycling(
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

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] RECV    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE    = 2'd3;
    
    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Bottle data storage (16 entries)
    reg signed [16:0] bin_dist_sq [0:15];
    reg signed [16:0] adil_dist_sq [0:15];
    reg signed [16:0] bera_dist_sq [0:15];
    reg signed [17:0] savings_adil [0:15];
    reg signed [17:0] savings_bera [0:15];

    // Bottle counter
    reg [3:0] bottle_cnt;

    // Top savings tracking
    reg signed [17:0] top1_adil, top2_adil;
    reg [3:0] top1_adil_idx, top2_adil_idx;
    reg signed [17:0] top1_bera, top2_bera;
    reg [3:0] top1_bera_idx, top2_bera_idx;

    // Intermediate results
    reg signed [32:0] total_base;
    reg signed [18:0] max_single, max_dual;

    // Distance calculation helpers
    function signed [16:0] dist_sq(input signed [15:0] x1, input signed [15:0] y1, input signed [15:0] x2, input signed [15:0] y2);
        reg signed [16:0] dx, dy;
        begin
            dx = x1 - x2;
            dy = y1 - y2;
            dist_sq = dx * dx + dy * dy;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            ready <= 1'b1;
            cycle_count <= 8'd0;
            bottle_cnt <= 4'd0;
            
            // Initialize all arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                bin_dist_sq[i] <= 17'd0;
                adil_dist_sq[i] <= 17'd0;
                bera_dist_sq[i] <= 17'd0;
                savings_adil[i] <= 18'd0;
                savings_bera[i] <= 18'd0;
            end
            
            // Initialize top savings
            top1_adil <= 18'd0; top1_adil_idx <= 4'd0;
            top2_adil <= 18'd0; top2_adil_idx <= 4'd0;
            top1_bera <= 18'd0; top1_bera_idx <= 4'd0;
            top2_bera <= 18'd0; top2_bera_idx <= 4'd0;
            
            total_base <= 33'd0;
            max_single <= 19'd0;
            max_dual <= 19'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        next_state <= RECV;
                        ready <= 1'b0;
                        bottle_cnt <= 4'd0;
                    end
                end
                
                RECV: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    
                    if (bottle_valid) begin
                        // Store current bottle data
                        bin_dist_sq[bottle_index] <= dist_sq(bin_x, bin_y, bottle_x, bottle_y);
                        adil_dist_sq[bottle_index] <= dist_sq(ax, ay, bottle_x, bottle_y);
                        bera_dist_sq[bottle_index] <= dist_sq(bx, by, bottle_x, bottle_y);
                        
                        // Calculate savings
                        savings_adil[bottle_index] <= 2 * bin_dist_sq[bottle_index] - adil_dist_sq[bottle_index];
                        savings_bera[bottle_index] <= 2 * bin_dist_sq[bottle_index] - bera_dist_sq[bottle_index];
                        
                        bottle_cnt <= bottle_cnt + 4'd1;
                        
                        if (bottle_cnt == 4'd15) begin
                            next_state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    
                    if (cycle_count == 8'd0) begin
                        // Initialize top savings
                        top1_adil <= savings_adil[0]; top1_adil_idx <= 4'd0;
                        top2_adil <= 18'd0; top2_adil_idx <= 4'd0;
                        top1_bera <= savings_bera[0]; top1_bera_idx <= 4'd0;
                        top2_bera <= 18'd0; top2_bera_idx <= 4'd0;
                        
                        // Calculate total base
                        integer i;
                        total_base <= 33'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            total_base <= total_base + bin_dist_sq[i];
                        end
                        total_base <= total_base * 2;
                    end
                    
                    // Find top 2 savings for Adil and Bera
                    if (cycle_count < 8'd16) begin
                        integer i = cycle_count;
                        
                        // Update Adil savings
                        if (savings_adil[i] > top1_adil) begin
                            top2_adil <= top1_adil;
                            top2_adil_idx <= top1_adil_idx;
                            top1_adil <= savings_adil[i];
                            top1_adil_idx <= i;
                        end else if (savings_adil[i] > top2_adil) begin
                            top2_adil <= savings_adil[i];
                            top2_adil_idx <= i;
                        end
                        
                        // Update Bera savings
                        if (savings_bera[i] > top1_bera) begin
                            top2_bera <= top1_bera;
                            top2_bera_idx <= top1_bera_idx;
                            top1_bera <= savings_bera[i];
                            top1_bera_idx <= i;
                        end else if (savings_bera[i] > top2_bera) begin
                            top2_bera <= savings_bera[i];
                            top2_bera_idx <= i;
                        end
                    end
                    
                    // Calculate max savings
                    if (cycle_count == 8'd16) begin
                        max_single <= top1_adil > top1_bera ? top1_adil : top1_bera;
                        
                        // Calculate max dual
                        if (top1_adil_idx != top1_bera_idx) begin
                            max_dual <= top1_adil + top1_bera;
                        end else begin
                            reg signed [18:0] option1, option2;
                            option1 = top1_adil + top2_bera;
                            option2 = top2_adil + top1_bera;
                            max_dual <= option1 > option2 ? option1 : option2;
                        end
                        
                        // Calculate final result
                        result <= total_base - (max_single > max_dual ? max_single : max_dual);
                        next_state <= DONE;
                    end
                    
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    ready <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    ready <= 1'b1;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule