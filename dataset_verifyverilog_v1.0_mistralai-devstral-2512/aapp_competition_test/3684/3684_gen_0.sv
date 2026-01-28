module max_min_buffer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] C,
    input wire [15:0] p [0:15],
    input wire [15:0] b [0:15],
    input wire [15:0] u [0:15],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] READ_INPUTS = 2'd1;
    localparam [1:0] BINARY_SEARCH = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal registers for inputs
    reg [3:0] n_reg;
    reg [7:0] C_reg;
    reg [15:0] p_reg [0:15];
    reg [15:0] b_reg [0:15];
    reg [15:0] u_reg [0:15];

    // Binary search variables
    reg signed [15:0] low;
    reg signed [15:0] high;
    reg signed [15:0] mid;
    reg [3:0] i;
    reg signed [31:0] total_deficit;
    reg signed [31:0] total_supply;
    reg feasible;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize internal registers
            n_reg <= 4'd0;
            C_reg <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                p_reg[i] <= 16'd0;
                b_reg[i] <= 16'd0;
                u_reg[i] <= 16'd0;
            end
            
            // Initialize binary search variables
            low <= 16'sd0;
            high <= 16'sd0;
            mid <= 16'sd0;
            total_deficit <= 32'sd0;
            total_supply <= 32'sd0;
            feasible <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= READ_INPUTS;
                    end
                end

                READ_INPUTS: begin
                    // Read inputs into internal registers
                    n_reg <= n;
                    C_reg <= C;
                    for (i = 0; i < 16; i = i + 1) begin
                        p_reg[i] <= p[i];
                        b_reg[i] <= b[i];
                        u_reg[i] <= u[i];
                    end
                    
                    // Initialize binary search bounds
                    low <= -16'sd256;
                    high <= 16'sd256;
                    state <= BINARY_SEARCH;
                end

                BINARY_SEARCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Binary search for B
                    if (low <= high) begin
                        mid <= (low + high) / 2;
                        
                        // Feasibility check for mid
                        total_deficit <= 32'sd0;
                        total_supply <= 32'sd0;
                        
                        for (i = 0; i < n_reg; i = i + 1) begin
                            // Calculate deficit for user i
                            if (b_reg[i] < (p_reg[i] + C_reg + mid)) begin
                                total_deficit <= total_deficit + ((p_reg[i] + C_reg + mid) - b_reg[i]);
                            end
                            
                            // Calculate supply for user i (if they have surplus)
                            if (b_reg[i] > (p_reg[i] + C_reg + mid)) begin
                                total_supply <= total_supply + u_reg[i];
                            end
                        end
                        
                        // Check feasibility
                        if (total_supply >= total_deficit) begin
                            feasible <= 1'b1;
                            low <= mid + 16'sd1;  // Try higher B
                        end else begin
                            feasible <= 1'b0;
                            high <= mid - 16'sd1; // Try lower B
                        end
                    end else begin
                        // Binary search complete
                        if (feasible) begin
                            result <= mid;
                        end else begin
                            result <= high;
                        end
                        state <= FINISH;
                    end
                    
                    // Prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule