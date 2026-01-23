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

    // Internal state
    reg [1:0] state;
    reg [3:0] x0, x1, x2, x3;           // Current transaction counts
    reg [15:0] max_profit;              // Best profit found
    reg [15:0] current_profit;          // Profit for current combo
    reg valid_combo;                    // Whether current combo is valid
    
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] UPDATE = 2'd2;
    localparam [1:0] FINISHED = 2'd3;
    
    // Helper: calculate f(i) value (convert 1-based to 0-based indexing)
    wire [3:0] f_val0 = f0 - 1;
    wire [3:0] f_val1 = f1 - 1;
    wire [3:0] f_val2 = f2 - 1;
    wire [3:0] f_val3 = f3 - 1;
    
    // Helper: profit per transaction for each i
    wire signed [15:0] profit_per0 = {8'd0, m1} - {8'd0, p0} when f_val0==1 else
                                   {8'd0, m2} - {8'd0, p0} when f_val0==2 else
                                   {8'd0, m3} - {8'd0, p0} when f_val0==3 else
                                   {8'd0, m0} - {8'd0, p0};
    wire signed [15:0] profit_per1 = {8'd0, m1} - {8'd0, p1} when f_val1==1 else
                                   {8'd0, m2} - {8'd0, p1} when f_val1==2 else
                                   {8'd0, m3} - {8'd0, p1} when f_val1==3 else
                                   {8'd0, m0} - {8'd0, p1};
    wire signed [15:0] profit_per2 = {8'd0, m1} - {8'd0, p2} when f_val2==1 else
                                   {8'd0, m2} - {8'd0, p2} when f_val2==2 else
                                   {8'd0, m3} - {8'd0, p2} when f_val2==3 else
                                   {8'd0, m0} - {8'd0, p2};
    wire signed [15:0] profit_per3 = {8'd0, m1} - {8'd0, p3} when f_val3==1 else
                                   {8'd0, m2} - {8'd0, p3} when f_val3==2 else
                                   {8'd0, m3} - {8'd0, p3} when f_val3==3 else
                                   {8'd0, m0} - {8'd0, p3};
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            profit <= 16'd0;
            done <= 1'b0;
            x0 <= 4'd0; x1 <= 4'd0; x2 <= 4'd0; x3 <= 4'd0;
            max_profit <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COMPUTE;
                        x0 <= 4'd0; x1 <= 4'd0; x2 <= 4'd0; x3 <= 4'd0;
                        max_profit <= 16'd0;
                        done <= 1'b0;
                    end
                end
                
                COMPUTE: begin
                    // Check constraints and calculate profit
                    valid_combo <= 1'b1;
                    current_profit <= 16'd0;
                    
                    // Constraint check: x_j + sum_{k: f(k)=j} x_k <= s_j
                    // For j=0: x0 + count of i where f(i)=0
                    if (x0 + ((f_val1==0 ? x1 : 4'd0) + (f_val2==0 ? x2 : 4'd0) + (f_val3==0 ? x3 : 4'd0)) > s0)
                        valid_combo <= 1'b0;
                    if (x1 + ((f_val0==1 ? x0 : 4'd0) + (f_val2==1 ? x2 : 4'd0) + (f_val3==1 ? x3 : 4'd0)) > s1)
                        valid_combo <= 1'b0;
                    if (x2 + ((f_val0==2 ? x0 : 4'd0) + (f_val1==2 ? x1 : 4'd0) + (f_val3==2 ? x3 : 4'd0)) > s2)
                        valid_combo <= 1'b0;
                    if (x3 + ((f_val0==3 ? x0 : 4'd0) + (f_val1==3 ? x1 : 4'd0) + (f_val2==3 ? x2 : 4'd0)) > s3)
                        valid_combo <= 1'b0;
                    
                    // Calculate profit if valid
                    if (valid_combo) begin
                        current_profit <= x0 * profit_per0 + x1 * profit_per1 + 
                                         x2 * profit_per2 + x3 * profit_per3;
                    end
                    
                    state <= UPDATE;
                end
                
                UPDATE: begin
                    if (valid_combo && current_profit > max_profit) begin
                        max_profit <= current_profit;
                    end
                    
                    // Increment counters (like nested loops)
                    if (x3 < s3) begin
                        x3 <= x3 + 4'd1;
                    end else begin
                        x3 <= 4'd0;
                        if (x2 < s2) begin
                            x2 <= x2 + 4'd1;
                        end else begin
                            x2 <= 4'd0;
                            if (x1 < s1) begin
                                x1 <= x1 + 4'd1;
                            end else begin
                                x1 <= 4'd0;
                                if (x0 < s0) begin
                                    x0 <= x0 + 4'd1;
                                end else begin
                                    // Finished all combinations
                                    profit <= max_profit;
                                    state <= FINISHED;
                                    done <= 1'b1;
                                end
                            end
                        end
                    end
                    
                    // If not finished, go back to compute next combination
                    if (state != FINISHED)
                        state <= COMPUTE;
                end
                
                FINISHED: begin
                    done <= 1'b0;
                    if (!start) state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule