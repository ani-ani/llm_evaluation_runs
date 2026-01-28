module street_widening #(
    parameter MAX_N = 16,
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0][DATA_WIDTH-1:0] s_in,
    input wire [15:0][DATA_WIDTH-1:0] g_in,
    output reg [DATA_WIDTH*2-1:0] total_removed,
    output reg [15:0][DATA_WIDTH-1:0] s_out,
    output reg done,
    output reg error
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] FORWARD = 2'd1;
    localparam [1:0] BACKWARD = 2'd2;
    localparam [1:0] VALIDATE = 2'd3;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Intermediate registers
    reg [15:0][DATA_WIDTH-1:0] upper_bounds;
    reg [15:0][DATA_WIDTH-1:0] lower_bounds;
    reg [15:0][DATA_WIDTH-1:0] new_s;

    // Forward pass variables
    reg [3:0] forward_idx;
    reg [DATA_WIDTH-1:0] current_upper;

    // Backward pass variables
    reg [3:0] backward_idx;
    reg [DATA_WIDTH-1:0] current_lower;

    // Validation variables
    reg [3:0] validate_idx;
    reg [DATA_WIDTH*2-1:0] total_removed_acc;
    reg solution_exists;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
            total_removed <= {DATA_WIDTH{1'b0}};
            
            for (i = 0; i < MAX_N; i = i + 1) begin
                upper_bounds[i] <= {DATA_WIDTH{1'b0}};
                lower_bounds[i] <= {DATA_WIDTH{1'b0}};
                new_s[i] <= {DATA_WIDTH{1'b0}};
                s_out[i] <= {DATA_WIDTH{1'b0}};
            end
            
            forward_idx <= 4'd0;
            current_upper <= {DATA_WIDTH{1'b0}};
            backward_idx <= 4'd0;
            current_lower <= {DATA_WIDTH{1'b0}};
            validate_idx <= 4'd0;
            total_removed_acc <= {DATA_WIDTH*2{1'b0}};
            solution_exists <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        state <= FORWARD;
                        forward_idx <= 4'd0;
                        current_upper <= s_in[0];
                        upper_bounds[0] <= s_in[0];
                    end
                end

                FORWARD: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (forward_idx < n - 1) begin
                        // Compute upper bound for next element
                        current_upper = s_in[forward_idx + 1] + g_in[forward_idx];
                        upper_bounds[forward_idx + 1] <= current_upper;
                        forward_idx <= forward_idx + 4'd1;
                    end else begin
                        // Forward pass complete
                        state <= BACKWARD;
                        backward_idx <= n - 1;
                        current_lower <= s_in[n - 1];
                        lower_bounds[n - 1] <= s_in[n - 1];
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                        error <= 1'b1;
                    end
                end

                BACKWARD: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (backward_idx > 0) begin
                        // Compute lower bound for previous element
                        current_lower = s_in[backward_idx - 1] + g_in[backward_idx - 1];
                        lower_bounds[backward_idx - 1] <= current_lower;
                        backward_idx <= backward_idx - 4'd1;
                    end else begin
                        // Backward pass complete
                        state <= VALIDATE;
                        validate_idx <= 4'd0;
                        total_removed_acc <= {DATA_WIDTH*2{1'b0}};
                        solution_exists <= 1'b1;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                        error <= 1'b1;
                    end
                end

                VALIDATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (validate_idx < n) begin
                        // Check if solution exists
                        if (lower_bounds[validate_idx] > upper_bounds[validate_idx]) begin
                            solution_exists <= 1'b0;
                        end
                        
                        // Compute new road width
                        new_s[validate_idx] <= (lower_bounds[validate_idx] + upper_bounds[validate_idx]) >> 1;
                        
                        // Accumulate total removed
                        if (validate_idx > 0) begin
                            reg [DATA_WIDTH*2-1:0] removed;
                            removed = (g_in[validate_idx - 1] - (new_s[validate_idx] - s_in[validate_idx - 1]));
                            total_removed_acc <= total_removed_acc + removed;
                        end
                        
                        validate_idx <= validate_idx + 4'd1;
                    end else begin
                        // Validation complete
                        if (solution_exists) begin
                            for (i = 0; i < MAX_N; i = i + 1) begin
                                s_out[i] <= new_s[i];
                            end
                            total_removed <= total_removed_acc;
                            done <= 1'b1;
                            error <= 1'b0;
                        end else begin
                            error <= 1'b1;
                            done <= 1'b0;
                        end
                        state <= IDLE;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                        error <= 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                    error <= 1'b1;
                end
            endcase
        end
    end
endmodule