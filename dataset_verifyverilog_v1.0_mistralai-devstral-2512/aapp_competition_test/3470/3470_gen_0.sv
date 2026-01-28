module minesweeper_corner(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] n,
    output reg done,
    output reg [12:0] result_count,
    output reg [12:0] result_indices [0:4003],
    output reg result_valid
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [9:0] current_n;
    reg [12:0] safe_count;
    reg [12:0] index;
    reg [12:0] output_index;
    reg [12:0] total_red_cells;
    reg n_parity;
    reg [12:0] i;
    
    // Initialize all result indices to 0
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_count <= 13'd0;
            result_valid <= 1'b0;
            safe_count <= 13'd0;
            index <= 13'd0;
            output_index <= 13'd0;
            total_red_cells <= 13'd0;
            n_parity <= 1'b0;
            i <= 13'd0;
            
            // Initialize result_indices array
            for (k = 0; k < 4004; k = k + 1) begin
                result_indices[k] <= 13'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    if (start) begin
                        current_n <= n;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Calculate total red cells: 4*n + 4
                    total_red_cells <= current_n * 4 + 13'd4;
                    n_parity <= current_n[0]; // LSB determines parity
                    
                    // Reset counters
                    safe_count <= 13'd0;
                    output_index <= 13'd0;
                    i <= 13'd1; // Start from index 1
                    
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    // Check if we've processed all indices
                    if (i > total_red_cells) begin
                        state <= FINISH;
                    end else begin
                        // Check if current index is safe
                        if ((n_parity == 1'b1 && i[0] == 1'b1) || (n_parity == 1'b0 && i[0] == 1'b0)) begin
                            // Store safe index
                            result_indices[output_index] <= i;
                            safe_count <= safe_count + 13'd1;
                            output_index <= output_index + 13'd1;
                        end
                        
                        // Increment index
                        i <= i + 13'd1;
                    end
                end
                
                FINISH: begin
                    result_count <= safe_count;
                    result_valid <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Combinational logic for parity check
    assign n_parity = current_n[0];

endmodule