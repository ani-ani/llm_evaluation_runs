module bookcase_optimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N_in,
    input wire [7:0] h_i [0:7],
    input wire [7:0] t_i [0:7],
    output reg [31:0] result,
    output reg done,
    output reg error
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] RESULT = 2'd2;
    
    reg [1:0] state;
    reg [7:0] N;
    reg [7:0] h [0:7];
    reg [7:0] t [0:7];
    reg [7:0] book_index;
    reg [7:0] shelf1_count;
    reg [7:0] shelf2_count;
    reg [7:0] shelf3_count;
    reg [8:0] max_h1;
    reg [8:0] max_h2;
    reg [8:0] max_h3;
    reg [15:0] total_t1;
    reg [15:0] total_t2;
    reg [15:0] total_t3;
    reg [31:0] min_area;
    reg [31:0] current_area;
    reg [7:0] i, j, k;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            result <= 32'd0;
            book_index <= 8'd0;
            shelf1_count <= 8'd0;
            shelf2_count <= 8'd0;
            shelf3_count <= 8'd0;
            max_h1 <= 9'd0;
            max_h2 <= 9'd0;
            max_h3 <= 9'd0;
            total_t1 <= 16'd0;
            total_t2 <= 16'd0;
            total_t3 <= 16'd0;
            min_area <= 32'd0;
            current_area <= 32'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        N <= N_in;
                        if (N < 8'd3) begin
                            error <= 1'b1;
                            state <= IDLE;
                        end else begin
                            for (i = 0; i < 8; i = i + 1) begin
                                h[i] <= h_i[i];
                                t[i] <= t_i[i];
                            end
                            state <= PROCESS;
                            book_index <= 8'd0;
                            shelf1_count <= 8'd0;
                            shelf2_count <= 8'd0;
                            shelf3_count <= 8'd0;
                            max_h1 <= 9'd0;
                            max_h2 <= 9'd0;
                            max_h3 <= 9'd0;
                            total_t1 <= 16'd0;
                            total_t2 <= 16'd0;
                            total_t3 <= 16'd0;
                            min_area <= 32'd0;
                            current_area <= 32'd0;
                            cycle_count <= 8'd0;
                        end
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= RESULT;
                    end else begin
                        // Initialize for new partition
                        if (book_index == 8'd0) begin
                            shelf1_count <= 8'd0;
                            shelf2_count <= 8'd0;
                            shelf3_count <= 8'd0;
                            max_h1 <= 9'd0;
                            max_h2 <= 9'd0;
                            max_h3 <= 9'd0;
                            total_t1 <= 16'd0;
                            total_t2 <= 16'd0;
                            total_t3 <= 16'd0;
                        end
                        
                        // Assign book to shelf 1
                        if (book_index < N) begin
                            // Try shelf 1
                            if (shelf1_count < N) begin
                                max_h1 <= (h[book_index] > max_h1) ? h[book_index] : max_h1;
                                total_t1 <= total_t1 + t[book_index];
                                shelf1_count <= shelf1_count + 8'd1;
                                book_index <= book_index + 8'd1;
                            end
                            // Try shelf 2
                            else if (shelf2_count < N) begin
                                max_h2 <= (h[book_index] > max_h2) ? h[book_index] : max_h2;
                                total_t2 <= total_t2 + t[book_index];
                                shelf2_count <= shelf2_count + 8'd1;
                                book_index <= book_index + 8'd1;
                            end
                            // Try shelf 3
                            else if (shelf3_count < N) begin
                                max_h3 <= (h[book_index] > max_h3) ? h[book_index] : max_h3;
                                total_t3 <= total_t3 + t[book_index];
                                shelf3_count <= shelf3_count + 8'd1;
                                book_index <= book_index + 8'd1;
                            end
                        end
                        
                        // Check if all books assigned
                        if (book_index == N) begin
                            // Calculate area
                            current_area <= (max_h1 + max_h2 + max_h3) * 
                                          (total_t1 > total_t2 ? (total_t1 > total_t3 ? total_t1 : total_t3) : 
                                           (total_t2 > total_t3 ? total_t2 : total_t3));
                            
                            // Update min area
                            if (min_area == 32'd0 || current_area < min_area) begin
                                min_area <= current_area;
                            end
                            
                            // Reset for next partition
                            book_index <= 8'd0;
                        end
                        
                        // Check if all partitions tried
                        if (book_index == 8'd0 && shelf1_count == N && shelf2_count == N && shelf3_count == N) begin
                            state <= RESULT;
                        end
                    end
                end
                
                RESULT: begin
                    done <= 1'b1;
                    result <= min_area;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule