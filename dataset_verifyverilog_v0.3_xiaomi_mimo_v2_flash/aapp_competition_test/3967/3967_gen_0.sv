module MaxIntervalD(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] a [0:7],
    input [15:0] k,
    output reg [7:0] max_d,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] ITERATE_D  = 3'd1;
    localparam [2:0] COMPUTE_SUM = 3'd2;
    localparam [2:0] CHECK      = 3'd3;
    localparam [2:0] UPDATE     = 3'd4;
    localparam [2:0] COMPLETE   = 3'd5;

    // Registers
    reg [2:0] state;
    reg [7:0] d;
    reg [7:0] i;
    reg [15:0] sum;
    reg [15:0] cut_len;
    reg [7:0] ceil_val;
    reg [7:0] current_max_d;
    reg [7:0] a_reg [0:7];
    
    // Constants
    localparam [7:0] D_MAX = 8'd256;
    localparam [15:0] MAX_K = 16'd65535;
    
    // Combinational signals
    wire [15:0] term;
    wire sum_le_k;
    wire i_lt_n;
    wire d_lt_dmax;
    
    // Assignments for comparators
    assign i_lt_n = (i < n);
    assign d_lt_dmax = (d < D_MAX);
    assign sum_le_k = (sum <= k);
    
    // Combinational logic for cut computation
    // ceil(a_i / d) = (a_i + d - 1) / d
    // Then multiply by d and subtract a_i
    always @(*) begin
        if (d == 8'd0) begin
            ceil_val = 8'd0;
            cut_len = 16'd0;
        end else begin
            ceil_val = (a_reg[i] + d - 8'd1) / d;
            cut_len = (ceil_val * d) - a_reg[i];
        end
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_d <= 8'd0;
            done <= 1'b0;
            d <= 8'd1;
            i <= 8'd0;
            sum <= 16'd0;
            current_max_d <= 8'd0;
            // Initialize a_reg array
            a_reg[0] <= 8'd0;
            a_reg[1] <= 8'd0;
            a_reg[2] <= 8'd0;
            a_reg[3] <= 8'd0;
            a_reg[4] <= 8'd0;
            a_reg[5] <= 8'd0;
            a_reg[6] <= 8'd0;
            a_reg[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load input array into local register
                        a_reg[0] <= a[0];
                        a_reg[1] <= a[1];
                        a_reg[2] <= a[2];
                        a_reg[3] <= a[3];
                        a_reg[4] <= a[4];
                        a_reg[5] <= a[5];
                        a_reg[6] <= a[6];
                        a_reg[7] <= a[7];
                        d <= 8'd1;
                        current_max_d <= 8'd0;
                        state <= ITERATE_D;
                    end
                end
                
                ITERATE_D: begin
                    i <= 8'd0;
                    sum <= 16'd0;
                    state <= COMPUTE_SUM;
                end
                
                COMPUTE_SUM: begin
                    if (i_lt_n) begin
                        sum <= sum + cut_len;
                        i <= i + 8'd1;
                    end else begin
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    if (sum_le_k) begin
                        state <= UPDATE;
                    end else begin
                        state <= ITERATE_D;
                        d <= d + 8'd1;
                    end
                end
                
                UPDATE: begin
                    current_max_d <= d;
                    d <= d + 8'd1;
                    state <= ITERATE_D;
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    max_d <= current_max_d;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Check for completion condition after UPDATE
            if (state == UPDATE && d == D_MAX) begin
                state <= COMPLETE;
            end else if (state == ITERATE_D && !d_lt_dmax && d != 8'd0) begin
                // d has reached D_MAX, go to complete
                if (d >= D_MAX) begin
                    state <= COMPLETE;
                end
            end
        end
    end
endmodule