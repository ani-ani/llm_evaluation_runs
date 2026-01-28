module max_profit (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Configuration for 4 snack positions
    input wire [3:0] f0, f1, f2, f3,    // f(i) values (1-4)
    input wire [7:0] p0, p1, p2, p3,    // buy prices
    input wire [7:0] m0, m1, m2, m3,    // market prices  
    input wire [3:0] s0, s1, s2, s3,    // stock counts
    
    output reg [15:0] profit,           // Maximum net gain
    output reg done                     // Computation complete
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COMPUTE   = 2'd1;
    localparam [1:0] UPDATE    = 2'd2;
    localparam [1:0] FINISHED  = 2'd3;
    
    // Internal state
    reg [1:0] state, next_state;
    reg [3:0] x0, x1, x2, x3;           // Current transaction counts
    reg [15:0] max_profit_reg;          // Best profit found
    reg [15:0] current_profit;          // Profit for current combo
    reg valid_combo;                    // Whether current combo is valid
    reg [7:0] cycle_counter;            // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd250;
    
    // Helper: profit per transaction for each i (converted to signed)
    wire signed [15:0] profit_per_0;
    wire signed [15:0] profit_per_1;
    wire signed [15:0] profit_per_2;
    wire signed [15:0] profit_per_3;
    
    // f(i) values are 1-based, convert to 0-based for indexing
    wire [1:0] f_val_0, f_val_1, f_val_2, f_val_3;
    assign f_val_0 = f0 - 4'd1;
    assign f_val_1 = f1 - 4'd1;
    assign f_val_2 = f2 - 4'd1;
    assign f_val_3 = f3 - 4'd1;
    
    // Calculate profit per transaction for each snack position
    assign profit_per_0 = (f_val_0 == 2'd0) ? ({8'd0, m1} - {8'd0, p0}) :
                          (f_val_0 == 2'd1) ? ({8'd0, m2} - {8'd0, p0}) :
                          (f_val_0 == 2'd2) ? ({8'd0, m3} - {8'd0, p0}) :
                                               ({8'd0, m0} - {8'd0, p0});
    
    assign profit_per_1 = (f_val_1 == 2'd0) ? ({8'd0, m1} - {8'd0, p1}) :
                          (f_val_1 == 2'd1) ? ({8'd0, m2} - {8'd0, p1}) :
                          (f_val_1 == 2'd2) ? ({8'd0, m3} - {8'd0, p1}) :
                                               ({8'd0, m0} - {8'd0, p1});
    
    assign profit_per_2 = (f_val_2 == 2'd0) ? ({8'd0, m1} - {8'd0, p2}) :
                          (f_val_2 == 2'd1) ? ({8'd0, m2} - {8'd0, p2}) :
                          (f_val_2 == 2'd2) ? ({8'd0, m3} - {8'd0, p2}) :
                                               ({8'd0, m0} - {8'd0, p2});
    
    assign profit_per_3 = (f_val_3 == 2'd0) ? ({8'd0, m1} - {8'd0, p3}) :
                          (f_val_3 == 2'd1) ? ({8'd0, m2} - {8'd0, p3}) :
                          (f_val_3 == 2'd2) ? ({8'd0, m3} - {8'd0, p3}) :
                                               ({8'd0, m0} - {8'd0, p3});
    
    // Helper: count how many positions map to each stock
    wire [3:0] count_map_to_0, count_map_to_1, count_map_to_2, count_map_to_3;
    assign count_map_to_0 = (f_val_0 == 2'd0 ? 4'd1 : 4'd0) + (f_val_1 == 2'd0 ? 4'd1 : 4'd0) + 
                            (f_val_2 == 2'd0 ? 4'd1 : 4'd0) + (f_val_3 == 2'd0 ? 4'd1 : 4'd0);
    assign count_map_to_1 = (f_val_0 == 2'd1 ? 4'd1 : 4'd0) + (f_val_1 == 2'd1 ? 4'd1 : 4'd0) + 
                            (f_val_2 == 2'd1 ? 4'd1 : 4'd0) + (f_val_3 == 2'd1 ? 4'd1 : 4'd0);
    assign count_map_to_2 = (f_val_0 == 2'd2 ? 4'd1 : 4'd0) + (f_val_1 == 2'd2 ? 4'd1 : 4'd0) + 
                            (f_val_2 == 2'd2 ? 4'd1 : 4'd0) + (f_val_3 == 2'd2 ? 4'd1 : 4'd0);
    assign count_map_to_3 = (f_val_0 == 2'd3 ? 4'd1 : 4'd0) + (f_val_1 == 2'd3 ? 4'd1 : 4'd0) + 
                            (f_val_2 == 2'd3 ? 4'd1 : 4'd0) + (f_val_3 == 2'd3 ? 4'd1 : 4'd0);
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            profit <= 16'd0;
            done <= 1'b0;
            x0 <= 4'd0;
            x1 <= 4'd0;
            x2 <= 4'd0;
            x3 <= 4'd0;
            max_profit_reg <= 16'd0;
            current_profit <= 16'd0;
            valid_combo <= 1'b1;
            cycle_counter <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        x0 <= 4'd0;
                        x1 <= 4'd0;
                        x2 <= 4'd0;
                        x3 <= 4'd0;
                        max_profit_reg <= 16'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Check constraints for current combination
                    // Constraint: x_j + sum_{k: f(k)=j} x_k <= s_j
                    valid_combo <= 1'b1;
                    
                    // Check stock 0 constraint
                    if ((x0 + ((f_val_1 == 2'd0 ? x1 : 4'd0) + 
                                (f_val_2 == 2'd0 ? x2 : 4'd0) + 
                                (f_val_3 == 2'd0 ? x3 : 4'd0))) > s0) begin
                        valid_combo <= 1'b0;
                    end
                    
                    // Check stock 1 constraint
                    if ((x1 + ((f_val_0 == 2'd1 ? x0 : 4'd0) + 
                                (f_val_2 == 2'd1 ? x2 : 4'd0) + 
                                (f_val_3 == 2'd1 ? x3 : 4'd0))) > s1) begin
                        valid_combo <= 1'b0;
                    end
                    
                    // Check stock 2 constraint
                    if ((x2 + ((f_val_0 == 2'd2 ? x0 : 4'd0) + 
                                (f_val_1 == 2'd2 ? x1 : 4'd0) + 
                                (f_val_3 == 2'd2 ? x3 : 4'd0))) > s2) begin
                        valid_combo <= 1'b0;
                    end
                    
                    // Check stock 3 constraint
                    if ((x3 + ((f_val_0 == 2'd3 ? x0 : 4'd0) + 
                                (f_val_1 == 2'd3 ? x1 : 4'd0) + 
                                (f_val_2 == 2'd3 ? x2 : 4'd0))) > s3) begin
                        valid_combo <= 1'b0;
                    end
                    
                    // Calculate profit for valid combo
                    if (valid_combo) begin
                        current_profit <= (
                            (x0 * profit_per_0) + 
                            (x1 * profit_per_1) + 
                            (x2 * profit_per_2) + 
                            (x3 * profit_per_3)
                        );
                    end
                    
                    state <= UPDATE;
                end
                
                UPDATE: begin
                    // Update max profit if current combo is valid
                    if (valid_combo && (current_profit > max_profit_reg)) begin
                        max_profit_reg <= current_profit;
                    end
                    
                    // Increment transaction counts (simulate nested loops)
                    if (x3 < s3) begin
                        x3 <= x3 + 4'd1;
                        state <= COMPUTE;
                    end else begin
                        x3 <= 4'd0;
                        if (x2 < s2) begin
                            x2 <= x2 + 4'd1;
                            state <= COMPUTE;
                        end else begin
                            x2 <= 4'd0;
                            if (x1 < s1) begin
                                x1 <= x1 + 4'd1;
                                state <= COMPUTE;
                            end else begin
                                x1 <= 4'd0;
                                if (x0 < s0) begin
                                    x0 <= x0 + 4'd1;
                                    state <= COMPUTE;
                                end else begin
                                    // All combinations processed
                                    profit <= max_profit_reg;
                                    state <= FINISHED;
                                    done <= 1'b1;
                                end
                            end
                        end
                    end
                    
                    // Prevent infinite loops
                    if (cycle_counter >= MAX_CYCLES) begin
                        profit <= max_profit_reg;
                        state <= FINISHED;
                        done <= 1'b1;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b0;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule