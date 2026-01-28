module pair_count (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr_in [0:15],
    input wire [3:0] len,
    input wire signed [7:0] target_sum,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;
    
    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] pair_count;
    reg [3:0] i_reg, j_reg;
    reg [7:0] arr_reg [0:15];
    reg [3:0] len_reg;
    reg signed [7:0] target_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pair_count <= 8'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            done <= 1'b0;
            result <= 8'd0;
            cycle_count <= 8'd0;
            
            // Initialize array
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                arr_reg[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (cycle_count >= MAX_CYCLES || (i_reg == len_reg - 2'b1 && j_reg == len_reg - 1'b1)) begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Load array and parameters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine
        end else if (state == LOAD) begin
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                arr_reg[k] <= arr_in[k];
            end
            len_reg <= len;
            target_reg <= target_sum;
            pair_count <= 8'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            cycle_count <= 8'd0;
        end
    end

    // Compute pairs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled
        end else if (state == COMPUTE) begin
            cycle_count <= cycle_count + 8'd1;
            
            // Check if current pair matches
            if (arr_reg[i_reg] + arr_reg[j_reg] == target_reg) begin
                if (pair_count < 8'd255) begin
                    pair_count <= pair_count + 8'd1;
                end
            end
            
            // Update indices
            if (j_reg == len_reg - 1'b1) begin
                i_reg <= i_reg + 4'd1;
                j_reg <= i_reg + 4'd1;
            end else begin
                j_reg <= j_reg + 4'd1;
            end
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 8'd0;
        end else begin
            done <= (state == DONE_STATE);
            result <= pair_count;
        end
    end

endmodule