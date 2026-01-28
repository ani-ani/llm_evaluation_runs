module GridColoring(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] R,
    input wire [3:0] C,
    input wire [15:0] a,
    input wire [15:0] b,
    input wire [15:0] c,
    output reg [255:0] grid,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CHECK   = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH  = 2'd3;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Internal signals
    reg [3:0] r_scaled;
    reg [3:0] c_scaled;
    reg [15:0] a_scaled;
    reg [15:0] b_scaled;
    reg [15:0] c_scaled;
    reg [3:0] color_pattern [0:3];
    reg [3:0] current_color;
    reg [3:0] row_idx;
    reg [3:0] col_idx;
    reg [3:0] pattern_idx;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            r_scaled <= 4'd0;
            c_scaled <= 4'd0;
            a_scaled <= 16'd0;
            b_scaled <= 16'd0;
            c_scaled <= 16'd0;
            color_pattern[0] <= 4'd1;  // A
            color_pattern[1] <= 4'd2;  // B
            color_pattern[2] <= 4'd3;  // C
            color_pattern[3] <= 4'd1;  // A
            current_color <= 4'd0;
            row_idx <= 4'd0;
            col_idx <= 4'd0;
            pattern_idx <= 4'd0;
            grid <= 256'd0;
            valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK;
                        // Scale inputs to 16x16 grid
                        r_scaled <= R;
                        c_scaled <= C;
                        a_scaled <= a;
                        b_scaled <= b;
                        c_scaled <= c;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if counts are feasible
                    // Total cells in scaled grid
                    reg [7:0] total_cells;
                    total_cells = r_scaled * c_scaled;
                    
                    // Check if counts match total cells
                    if ((a_scaled + b_scaled + c_scaled) == total_cells) begin
                        // Check if counts are compatible with pattern
                        // For 2x2 pattern: 2A, 1B, 1C per 4 cells
                        reg [7:0] expected_a;
                        reg [7:0] expected_b;
                        reg [7:0] expected_c;
                        expected_a = (total_cells / 4) * 2;
                        expected_b = (total_cells / 4) * 1;
                        expected_c = (total_cells / 4) * 1;
                        
                        if ((a_scaled == expected_a) && 
                            (b_scaled == expected_b) && 
                            (c_scaled == expected_c)) begin
                            state <= COMPUTE;
                            row_idx <= 4'd0;
                            col_idx <= 4'd0;
                            pattern_idx <= 4'd0;
                        end else begin
                            state <= FINISH;
                            valid <= 1'b0;
                        end
                    end else begin
                        state <= FINISH;
                        valid <= 1'b0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Generate 2x2 repeating pattern
                    // Pattern: A B A B
                    //          C A C A
                    //          A B A B
                    //          C A C A
                    
                    // Determine color based on position
                    reg [1:0] row_mod;
                    reg [1:0] col_mod;
                    row_mod = row_idx[1:0];
                    col_mod = col_idx[1:0];
                    
                    if ((row_mod == 2'd0 || row_mod == 2'd2) && 
                        (col_mod == 2'd0 || col_mod == 2'd2)) begin
                        current_color <= 4'd1;  // A
                    end else if ((row_mod == 2'd0 || row_mod == 2'd2) && 
                                (col_mod == 2'd1 || col_mod == 2'd3)) begin
                        current_color <= 4'd2;  // B
                    end else if ((row_mod == 2'd1 || row_mod == 2'd3) && 
                                (col_mod == 2'd0 || col_mod == 2'd2)) begin
                        current_color <= 4'd3;  // C
                    end else begin
                        current_color <= 4'd1;  // A
                    end
                    
                    // Write to grid
                    grid[(row_idx * 16) + col_idx] <= current_color;
                    
                    // Update indices
                    if (col_idx == c_scaled - 1) begin
                        if (row_idx == r_scaled - 1) begin
                            state <= FINISH;
                            valid <= 1'b1;
                        end else begin
                            col_idx <= 4'd0;
                            row_idx <= row_idx + 4'd1;
                        end
                    end else begin
                        col_idx <= col_idx + 4'd1;
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