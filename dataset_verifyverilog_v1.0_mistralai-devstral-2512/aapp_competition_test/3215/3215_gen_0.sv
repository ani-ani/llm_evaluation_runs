module riffle_shuffle(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] card_in,
    input wire valid_in,
    input wire [3:0] len,
    output reg [3:0] result,
    output reg done,
    output reg idle
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] card_count;
    reg [15:0] permutation [0:15];
    reg [15:0] visited [0:15];
    reg [3:0] max_cycle_length;
    reg [3:0] current_cycle_length;
    reg [3:0] current_index;
    reg [3:0] i, j;
    reg [3:0] temp_len;

    // FSM state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            idle <= 1'b1;
            card_count <= 4'd0;
            max_cycle_length <= 4'd0;
            current_cycle_length <= 4'd0;
            current_index <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            // Initialize permutation and visited arrays
            for (temp_len = 0; temp_len < 16; temp_len = temp_len + 1) begin
                permutation[temp_len] <= 16'd0;
                visited[temp_len] <= 1'b0;
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
                idle = 1'b1;
                if (start) begin
                    next_state = LOAD;
                    idle = 1'b0;
                end
            end
            
            LOAD: begin
                idle = 1'b0;
                if (card_count == len - 1 && valid_in) begin
                    next_state = PROCESS;
                end else if (valid_in) begin
                    next_state = LOAD;
                end
            end
            
            PROCESS: begin
                idle = 1'b0;
                // Check if all indices processed
                if (current_index == len - 1) begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                idle = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Load permutation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            card_count <= 4'd0;
        end else if (state == LOAD && valid_in) begin
            permutation[card_count] <= card_in;
            card_count <= card_count + 1;
        end
    end

    // Process permutation to find cycles
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_index <= 4'd0;
            max_cycle_length <= 4'd0;
            current_cycle_length <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            // Reset visited array
            for (temp_len = 0; temp_len < 16; temp_len = temp_len + 1) begin
                visited[temp_len] <= 1'b0;
            end
        end else if (state == PROCESS) begin
            // Find cycles in permutation
            if (current_index < len) begin
                if (!visited[current_index]) begin
                    // Start new cycle
                    i <= current_index;
                    current_cycle_length <= 1;
                    visited[i] <= 1'b1;
                    
                    // Trace cycle
                    j <= permutation[i] - 1;
                    while (j != current_index && current_cycle_length < 16) begin
                        if (!visited[j]) begin
                            visited[j] <= 1'b1;
                            current_cycle_length <= current_cycle_length + 1;
                            i <= j;
                            j <= permutation[i] - 1;
                        end else begin
                            j <= current_index;
                        end
                    end
                    
                    // Update max cycle length
                    if (current_cycle_length > max_cycle_length) begin
                        max_cycle_length <= current_cycle_length;
                    end
                end
                current_index <= current_index + 1;
            end
        end
    end

    // Calculate result (bit length of max_cycle_length)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 4'd0;
            done <= 1'b0;
        end else if (state == OUTPUT) begin
            // Calculate bit length
            if (max_cycle_length == 0) begin
                result <= 4'd0;
            end else if (max_cycle_length <= 1) begin
                result <= 4'd1;
            end else if (max_cycle_length <= 2) begin
                result <= 4'd2;
            end else if (max_cycle_length <= 4) begin
                result <= 4'd3;
            end else if (max_cycle_length <= 8) begin
                result <= 4'd4;
            end else begin
                result <= 4'd5;
            end
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule