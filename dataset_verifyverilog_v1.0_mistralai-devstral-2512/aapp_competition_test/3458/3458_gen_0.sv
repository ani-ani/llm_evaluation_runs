module max_xor_subset_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_count,
    input wire [63:0] data_in,
    output reg [63:0] result,
    output reg done,
    output reg input_ready
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] input_counter;
    reg [63:0] basis [0:63];
    reg [63:0] temp_basis [0:63];
    reg [5:0] basis_counter;
    reg [5:0] bit_counter;
    reg [5:0] inner_counter;
    reg [63:0] current_data;
    reg [63:0] max_result;
    reg [63:0] temp_result;
    reg [5:0] max_bit;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            input_counter <= 4'd0;
            basis_counter <= 6'd0;
            bit_counter <= 6'd0;
            inner_counter <= 6'd0;
            current_data <= 64'd0;
            max_result <= 64'd0;
            temp_result <= 64'd0;
            max_bit <= 6'd0;
            done <= 1'b0;
            input_ready <= 1'b0;
            result <= 64'd0;

            // Initialize basis arrays
            integer i;
            for (i = 0; i < 64; i = i + 1) begin
                basis[i] <= 64'd0;
                temp_basis[i] <= 64'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        input_ready = 1'b0;
        done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INPUT;
                    input_counter = 4'd0;
                    input_ready = 1'b1;
                end
            end

            INPUT: begin
                input_ready = 1'b1;
                if (input_counter == num_count - 1) begin
                    next_state = COMPUTE;
                    input_ready = 1'b0;
                end
            end

            COMPUTE: begin
                // Gaussian elimination phase
                if (bit_counter < 64) begin
                    if (inner_counter < num_count) begin
                        // Process each number
                        if (basis[bit_counter] == 64'd0) begin
                            if (current_data[bit_counter]) begin
                                temp_basis[bit_counter] = current_data;
                                // Eliminate this bit from other basis vectors
                                integer j;
                                for (j = 0; j < bit_counter; j = j + 1) begin
                                    if (temp_basis[j][bit_counter]) begin
                                        temp_basis[j] = temp_basis[j] ^ temp_basis[bit_counter];
                                    end
                                end
                            end
                        end else begin
                            if (current_data[bit_counter]) begin
                                current_data = current_data ^ basis[bit_counter];
                            end
                        end
                        inner_counter = inner_counter + 1;
                    end else begin
                        // Move to next bit
                        bit_counter = bit_counter + 1;
                        inner_counter = 6'd0;
                    end
                end else begin
                    // Compute maximum result
                    if (basis_counter < 64) begin
                        if (temp_basis[basis_counter] != 64'd0) begin
                            if ((temp_result ^ temp_basis[basis_counter]) > temp_result) begin
                                temp_result = temp_result ^ temp_basis[basis_counter];
                            end
                        end
                        basis_counter = basis_counter + 1;
                    end else begin
                        next_state = OUTPUT;
                    end
                end
            end

            OUTPUT: begin
                done = 1'b1;
                result = temp_result;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Input data sampling
    always @(posedge clk) begin
        if (state == INPUT && input_ready) begin
            current_data = data_in;
            input_counter = input_counter + 1;
        end
    end

    // Basis update after elimination
    always @(posedge clk) begin
        if (state == COMPUTE && bit_counter < 64 && inner_counter == num_count - 1) begin
            integer i;
            for (i = 0; i < 64; i = i + 1) begin
                basis[i] = temp_basis[i];
            end
        end
    end

endmodule