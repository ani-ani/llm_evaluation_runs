module food_arrangement(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire input_valid,
    input wire [4:0] input_a,
    input wire [4:0] input_b,
    input wire input_last,
    input wire [3:0] pair_index,
    output reg [1:0] result_a,
    output reg [1:0] result_b,
    output reg output_valid,
    output reg output_done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INPUT   = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] n;  // Number of pairs (n <= 16)
    reg [4:0] current_pair;  // Current pair being processed
    reg [4:0] compute_index;  // Index for compute state
    reg [4:0] output_index;  // Index for output state
    reg [4:0] partner [0:31];  // Partner array (5-bit indices)
    reg [1:0] color [0:31];  // Color array (0=unassigned, 1=Kooft, 2=Zahre-mar)
    reg [4:0] stored_a [0:15];  // Store input pairs
    reg [4:0] stored_b [0:15];
    reg [7:0] cycle_count;  // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            n <= 5'd0;
            current_pair <= 5'd0;
            compute_index <= 5'd0;
            output_index <= 5'd0;
            result_a <= 2'd0;
            result_b <= 2'd0;
            output_valid <= 1'b0;
            output_done <= 1'b0;
            error <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize arrays
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                partner[i] <= 5'd0;
                color[i] <= 2'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                stored_a[i] <= 5'd0;
                stored_b[i] <= 5'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    output_valid <= 1'b0;
                    output_done <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        next_state <= INPUT;
                        n <= 5'd0;
                        current_pair <= 5'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INPUT: begin
                    output_valid <= 1'b0;
                    output_done <= 1'b0;
                    if (input_valid) begin
                        // Store the pair
                        stored_a[current_pair] <= input_a;
                        stored_b[current_pair] <= input_b;
                        
                        // Update partner array
                        partner[input_a] <= input_b;
                        partner[input_b] <= input_a;
                        
                        // Update current pair
                        if (input_last) begin
                            n <= current_pair + 5'd1;
                            next_state <= COMPUTE;
                            compute_index <= 5'd0;
                        end else begin
                            current_pair <= current_pair + 5'd1;
                        end
                    end
                end

                COMPUTE: begin
                    output_valid <= 1'b0;
                    output_done <= 1'b0;
                    
                    // Check if all chairs are colored
                    reg all_colored;
                    integer i;
                    all_colored = 1'b1;
                    for (i = 0; i < 32; i = i + 1) begin
                        if (color[i] == 2'd0) begin
                            all_colored = 1'b0;
                        end
                    end
                    
                    if (all_colored) begin
                        next_state <= OUTPUT;
                        output_index <= 5'd0;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        error <= 1'b1;
                        next_state <= DONE;
                    end else begin
                        // Find next uncolored chair
                        if (color[compute_index] == 2'd0) begin
                            // Assign colors
                            color[compute_index] <= 2'd1;
                            color[compute_index ^ 5'd1] <= 2'd2;
                            
                            // Move to partner's partner
                            compute_index <= partner[compute_index ^ 5'd1];
                        end else begin
                            compute_index <= compute_index + 5'd1;
                        end
                    end
                end

                OUTPUT: begin
                    if (output_index < n) begin
                        result_a <= color[stored_a[output_index]];
                        result_b <= color[stored_b[output_index]];
                        output_valid <= 1'b1;
                        output_done <= 1'b0;
                        
                        if (output_index == n - 5'd1) begin
                            output_index <= output_index + 5'd1;
                            next_state <= DONE;
                        end else begin
                            output_index <= output_index + 5'd1;
                        end
                    end else begin
                        output_valid <= 1'b0;
                        output_done <= 1'b1;
                        next_state <= IDLE;
                    end
                end

                DONE: begin
                    output_valid <= 1'b0;
                    output_done <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    output_valid <= 1'b0;
                    output_done <= 1'b0;
                    error <= 1'b0;
                end
            endcase
        end
    end

endmodule