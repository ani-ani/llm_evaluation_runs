module discarding_operations_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] p [0:1023],
    input wire [9:0] m_valid,
    input wire [7:0] k_in,
    output reg done,
    output reg [9:0] result
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [9:0] i; // Iterator (0 to m_valid-1)
    reg [31:0] shift; // Number of items removed so far
    reg [31:0] ops_count; // Operation counter
    reg [31:0] prev_page; // Previous page number
    reg first_item; // Flag for first item
    reg [31:0] current_page; // Computed current page
    reg [31:0] idx_sub_shift; // Intermediate for subtraction
    reg [31:0] k_in_ext; // Extended page size
    
    // Temp registers for pipeline computation
    reg [31:0] temp_shift;
    reg [31:0] temp_ops;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 10'd0;
            shift <= 32'd0;
            ops_count <= 32'd0;
            prev_page <= 32'd0;
            first_item <= 1'b0;
            result <= 10'd0;
            done <= 1'b0;
            current_page <= 32'd0;
            idx_sub_shift <= 32'd0;
            k_in_ext <= 32'd0;
            temp_shift <= 32'd0;
            temp_ops <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        i <= 10'd0;
                        shift <= 32'd0;
                        ops_count <= 32'd0;
                        first_item <= 1'b1;
                        k_in_ext <= {24'd0, k_in};
                    end
                end
                
                PROCESS: begin
                    // Pipeline stage 1: Read index and subtract shift
                    if (i < m_valid) begin
                        idx_sub_shift <= {16'd0, p[i]} - shift;
                    end
                    
                    // Pipeline stage 2: Compute page (division by k)
                    // Note: Integer division logic for synthesis
                    // We calculate current_page = idx_sub_shift / k_in_ext
                    // For hardware, we use a simple approximation or direct assignment
                    // Since values are small, we can use built-in division if tool supports,
                    // but for strict Verilog compatibility, we might need an iterative divider.
                    // Given the constraints and typical synthesis tools, direct division is often
                    // allowed for static or small values, but let's implement a basic logic
                    // to avoid synthesis issues on large divisions.
                    // However, for simplicity and since k is small (<=256), we can use:
                    // current_page = idx_sub_shift >> 3 (if k=8) is not general.
                    // Let's assume standard division operator '/' is supported for logic synthesis.
                    if (k_in_ext != 0) begin
                        current_page <= idx_sub_shift / k_in_ext;
                    end else begin
                        current_page <= 32'd0; // Avoid division by zero
                    end
                    
                    // Pipeline stage 3: Compare pages and update counters
                    if (i < m_valid) begin
                        if (first_item) begin
                            ops_count <= ops_count + 32'd1;
                            prev_page <= current_page;
                            first_item <= 1'b0;
                        end else begin
                            if (current_page != prev_page) begin
                                ops_count <= ops_count + 32'd1;
                                prev_page <= current_page;
                            end
                        end
                        // Increment shift for every item processed
                        shift <= shift + 32'd1;
                        i <= i + 10'd1;
                    end
                end
                
                FINISH: begin
                    result <= ops_count[9:0]; // Truncate to 10 bits
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = PROCESS;
                else next_state = IDLE;
            end
            PROCESS: begin
                if (i >= m_valid) next_state = FINISH;
                else next_state = PROCESS;
            end
            FINISH: begin
                next_state = IDLE; // Return to idle after done pulse
            end
            default: next_state = IDLE;
        endcase
    end

endmodule