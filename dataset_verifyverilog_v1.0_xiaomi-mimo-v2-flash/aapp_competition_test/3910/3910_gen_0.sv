module FoodArrangement(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire input_valid,
    input wire input_last,
    input wire [4:0] input_a,
    input wire [4:0] input_b,
    input wire [3:0] pair_index,
    output reg [1:0] result_a,
    output reg [1:0] result_b,
    output reg output_valid,
    output reg output_done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INPUT     = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    localparam [2:0] DONE      = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [4:0] partner [0:31];  // 5-bit index, stores partner chair index
    reg [1:0] color [0:31];    // 0: unassigned, 1: Kooft, 2: Zahre-mar
    reg [4:0] input_pair_a [0:15];  // Store original pairs for output
    reg [4:0] input_pair_b [0:15];
    
    // Control registers
    reg [3:0] pair_counter;    // Counts 0 to n-1 during input
    reg [4:0] chair_counter;   // Counts 0 to 31 during compute
    reg [3:0] output_counter;  // Counts 0 to n-1 during output
    reg [4:0] current_chair;
    reg error_reg;
    
    // Combinational signals
    wire [1:0] color_current;
    wire [1:0] color_opposite;
    wire [4:0] partner_opposite;
    
    // Assignments for current chair processing
    assign color_current = color[current_chair];
    assign color_opposite = color[current_chair ^ 1'b1];
    assign partner_opposite = partner[current_chair ^ 1'b1];

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result_a <= 2'd0;
            result_b <= 2'd0;
            output_valid <= 1'b0;
            output_done <= 1'b0;
            error <= 1'b0;
            error_reg <= 1'b0;
            pair_counter <= 4'd0;
            chair_counter <= 5'd0;
            output_counter <= 4'd0;
            current_chair <= 5'd0;
            
            // Initialize arrays
            for (integer i = 0; i < 32; i = i + 1) begin
                partner[i] <= 5'd0;
                color[i] <= 2'd0;
            end
            for (integer j = 0; j < 16; j = j + 1) begin
                input_pair_a[j] <= 5'd0;
                input_pair_b[j] <= 5'd0;
            end
        end else begin
            // Default outputs
            output_valid <= 1'b0;
            output_done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Reset all computation registers
                        for (integer i = 0; i < 32; i = i + 1) begin
                            color[i] <= 2'd0;
                        end
                        pair_counter <= 4'd0;
                        error_reg <= 1'b0;
                        error <= 1'b0;
                    end
                end
                
                INPUT: begin
                    if (input_valid) begin
                        // Store pair
                        input_pair_a[pair_counter] <= input_a;
                        input_pair_b[pair_counter] <= input_b;
                        
                        // Update partner array
                        partner[input_a] <= input_b;
                        partner[input_b] <= input_a;
                        
                        pair_counter <= pair_counter + 4'd1;
                    end
                end
                
                COMPUTE: begin
                    // Initialize for first chair if starting
                    if (chair_counter == 5'd0 && current_chair == 5'd0) begin
                        if (color[0] == 2'd0) begin
                            color[0] <= 2'd1;           // Kooft
                            color[1] <= 2'd2;           // Zahre-mar
                            current_chair <= partner[1]; // Move to partner of opposite chair
                        end
                    end else if (current_chair < 5'd32) begin
                        // Process current chair if uncolored
                        if (color[current_chair] == 2'd0) begin
                            color[current_chair] <= 2'd1;      // Kooft
                            color[current_chair ^ 1'b1] <= 2'd2; // Zahre-mar
                            current_chair <= partner[current_chair ^ 1'b1];
                        end else begin
                            // Already colored, move to next uncolored
                            if (current_chair < 5'd31) begin
                                current_chair <= current_chair + 5'd1;
                            end else begin
                                current_chair <= 5'd32; // Done
                            end
                        end
                    end
                end
                
                OUTPUT: begin
                    if (output_counter < pair_counter) begin
                        // Output colors for current pair
                        result_a <= color[input_pair_a[output_counter]];
                        result_b <= color[input_pair_b[output_counter]];
                        output_valid <= 1'b1;
                        output_counter <= output_counter + 4'd1;
                    end
                    
                    // Check for errors after computation
                    if (output_counter == 4'd0) begin
                        for (integer i = 0; i < 32; i = i + 1) begin
                            if (color[i] == 2'd0 && i < (pair_counter * 2)) begin
                                error_reg <= 1'b1;
                            end
                        end
                        error <= error_reg;
                    end
                end
                
                DONE: begin
                    output_done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic (combinational)
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = INPUT;
                else next_state = IDLE;
            end
            
            INPUT: begin
                if (input_valid && input_last) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = INPUT;
                end
            end
            
            COMPUTE: begin
                // Check if all chairs processed or no more uncolored chairs
                if (current_chair >= 5'd32) begin
                    next_state = OUTPUT;
                end else if (chair_counter >= 5'd32 && current_chair >= 5'd32) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            OUTPUT: begin
                if (output_counter >= pair_counter) begin
                    next_state = DONE;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule