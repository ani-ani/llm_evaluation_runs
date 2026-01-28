module arpa_land (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,           // Number of people (1-8)
    input wire [2:0] crush_0,     // Crush array (0-indexed)
    input wire [2:0] crush_1,
    input wire [2:0] crush_2,
    input wire [2:0] crush_3,
    input wire [2:0] crush_4,
    input wire [2:0] crush_5,
    input wire [2:0] crush_6,
    input wire [2:0] crush_7,
    output reg [9:0] result,      // LCM result or -1 (10'h3FF)
    output reg done               // Computation finished
);

// State definitions
localparam [3:0] S_IDLE = 4'd0;
localparam [3:0] S_INIT = 4'd1;
localparam [3:0] S_CHECK = 4'd2;
localparam [3:0] S_TRAVERSE = 4'd3;
localparam [3:0] S_ADJUST = 4'd4;
localparam [3:0] S_NEXT = 4'd5;
localparam [3:0] S_COMPUTE = 4'd6;
localparam [3:0] S_DONE = 4'd7;
localparam [3:0] S_ERROR = 4'd8;

// Registers
reg [3:0] state, next_state;
reg [2:0] n_reg;
reg [2:0] crush_reg [0:7];
reg visited [0:7];
reg [2:0] i;                  // Node counter
reg [2:0] current;            // Current node in traversal
reg [2:0] start_node;         // Start node of current cycle
reg [3:0] count;              // Cycle length counter
reg [1:0] max2;               // Max exponent of 2 in adjusted lengths
reg max3, max5, max7;         // Flags for primes
reg error;
reg [2:0] next_node;          // Temporary for traversal

// Combinational next_state logic
always @(*) begin
    next_state = state;
    case (state)
        S_IDLE: if (start) next_state = S_INIT;
        S_INIT: next_state = S_CHECK;
        S_CHECK: begin
            if (i < n_reg) begin
                if (!visited[i]) next_state = S_TRAVERSE;
                else next_state = S_NEXT;
            end else begin
                if (error) next_state = S_ERROR;
                else next_state = S_COMPUTE;
            end
        end
        S_TRAVERSE: begin
            if (visited[current]) begin
                if (current == start_node) next_state = S_ADJUST;
                else next_state = S_ERROR;
            end else begin
                next_state = S_TRAVERSE;
            end
        end
        S_ADJUST: next_state = S_NEXT;
        S_NEXT: next_state = S_CHECK;
        S_COMPUTE: next_state = S_DONE;
        S_DONE: next_state = S_DONE;
        S_ERROR: next_state = S_DONE;
        default: next_state = S_IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 0;
        result <= 0;
        n_reg <= 0;
        for (integer idx = 0; idx < 8; idx = idx + 1) begin
            crush_reg[idx] <= 0;
            visited[idx] <= 0;
        end
        i <= 0;
        current <= 0;
        start_node <= 0;
        count <= 0;
        max2 <= 0;
        max3 <= 0;
        max5 <= 0;
        max7 <= 0;
        error <= 0;
        next_node <= 0;
    end else begin
        state <= next_state;
        case (state)
            S_IDLE: begin
                done <= 0;
                if (start) begin
                    n_reg <= (n > 3'd0 && n <= 3'd8) ? n : 3'd8;
                    crush_reg[0] <= crush_0;
                    crush_reg[1] <= crush_1;
                    crush_reg[2] <= crush_2;
                    crush_reg[3] <= crush_3;
                    crush_reg[4] <= crush_4;
                    crush_reg[5] <= crush_5;
                    crush_reg[6] <= crush_6;
                    crush_reg[7] <= crush_7;
                    result <= 0;
                    error <= 0;
                end
            end
            S_INIT: begin
                // Initialize visited and factors
                for (integer idx = 0; idx < 8; idx = idx + 1) begin
                    visited[idx] <= (idx < n_reg) ? 1'b0 : 1'b1;
                end
                i <= 0;
                max2 <= 0;
                max3 <= 0;
                max5 <= 0;
                max7 <= 0;
            end
            S_CHECK: begin
                if (i < n_reg && visited[i]) begin
                    i <= i + 3'd1;
                end
            end
            S_TRAVERSE: begin
                if (!visited[current]) begin
                    visited[current] <= 1'b1;
                    next_node <= crush_reg[current];
                    current <= crush_reg[current];
                    count <= count + 4'd1;
                end else begin
                    // Already visited, will go to adjust or error
                end
            end
            S_ADJUST: begin
                // Adjust cycle length
                if (count[0] == 1'b0) begin // Even
                    count <= {1'b0, count[3:1]}; // Divide by 2
                end
                // Update factors based on adjusted count
                case (count)
                    4'd1: begin end // Do nothing
                    4'd2: begin
                        if (max2 < 2'd1) max2 <= 2'd1;
                    end
                    4'd3: begin
                        max3 <= 1'b1;
                    end
                    4'd4: begin
                        if (max2 < 2'd2) max2 <= 2'd2;
                    end
                    4'd5: begin
                        max5 <= 1'b1;
                    end
                    4'd7: begin
                        max7 <= 1'b1;
                    end
                    default: begin
                        // For other lengths, check factors
                        if (count[0] == 1'b0) begin // Even
                            if (count >= 8'd4) begin
                                if (max2 < 2'd2) max2 <= 2'd2;
                            end else begin
                                if (max2 < 2'd1) max2 <= 2'd1;
                            end
                        end else begin // Odd
                            if (count == 4'd3) max3 <= 1'b1;
                            else if (count == 4'd5) max5 <= 1'b1;
                            else if (count == 4'd7) max7 <= 1'b1;
                            else if (count >= 4'd9) error <= 1'b1;
                        end
                    end
                endcase
                // Reset count
                count <= 0;
            end
            S_NEXT: begin
                i <= i + 3'd1;
                if (i + 3'd1 < n_reg && !visited[i + 3'd1]) begin
                    current <= i + 3'd1;
                    start_node <= i + 3'd1;
                end
            end
            S_COMPUTE: begin
                // Compute LCM = (2^max2) * (3 if max3) * (5 if max5) * (7 if max7)
                // 2^max2
                result[9:0] <= 10'd1;
                if (max2 == 2'd1) result[9:0] <= 10'd2;
                if (max2 == 2'd2) result[9:0] <= 10'd4;
                if (max3) result[9:0] <= result[9:0] * 10'd3;
                if (max5) result[9:0] <= result[9:0] * 10'd5;
                if (max7) result[9:0] <= result[9:0] * 10'd7;
            end
            S_DONE: begin
                done <= 1'b1;
                if (error) begin
                    result <= 10'h3FF; // -1 in two's complement
                end
            end
            S_ERROR: begin
                error <= 1'b1;
            end
        endcase
    end
end

endmodule