module bookcase_optimizer(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_books,
    input [7:0] heights [0:7],
    input [7:0] thickness [0:7],
    output reg [15:0] min_area,
    output reg done
);

// State encoding
localparam IDLE = 3'b000;
localparam PREPROCESS = 3'b001;
localparam BRUTE_FORCE_CHECK = 3'b010;
localparam UPDATE_MIN = 3'b011;
localparam DONE = 3'b100;

reg [2:0] state;
reg [2:0] next_state;

// Book storage
reg [7:0] stored_heights [0:7];
reg [7:0] stored_thickness [0:7];
reg [2:0] stored_num_books;

// Combination counter (ternary representation)
reg [15:0] combo_counter;  // Holds the assignment as base-3 encoded value
reg [15:0] max_combo;

// Current assignment being evaluated
reg [1:0] book_assignment [0:7];  // 0, 1, or 2 for each book
reg [2:0] current_book_idx;

// Computation registers
reg [7:0] max_h0, max_h1, max_h2;
reg [7:0] sum_t0, sum_t1, sum_t2;
reg [15:0] current_area;
reg valid_assignment;

// Temporary computation registers
reg [7:0] temp_max_h;
reg [15:0] temp_sum_t;
reg [15:0] temp_product;
reg [7:0] max_t;

// Helper signals
reg [2:0] shelf_idx;
reg [15:0] combo_temp;
reg [2:0] digit;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        min_area <= 16'hFFFF;
        done <= 1'b0;
        combo_counter <= 16'b0;
        max_combo <= 16'b0;
        current_book_idx <= 3'b0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    stored_num_books <= num_books;
                    // Calculate max combo: 3^N - 1
                    if (num_books == 3'd3) max_combo <= 16'd26;      // 3^3 - 1 = 26
                    else if (num_books == 3'd4) max_combo <= 16'd80; // 3^4 - 1 = 80
                    else if (num_books == 3'd5) max_combo <= 16'd242; // 3^5 - 1 = 242
                    else if (num_books == 3'd6) max_combo <= 16'd728; // 3^6 - 1 = 728
                    else if (num_books == 3'd7) max_combo <= 16'd2186; // 3^7 - 1 = 2186
                    else if (num_books == 3'd8) max_combo <= 16'd6560; // 3^8 - 1 = 6560
                    combo_counter <= 16'b0;
                    min_area <= 16'hFFFF;
                end
            end
            
            PREPROCESS: begin
                // Store all book data
                stored_heights[0] <= heights[0];
                stored_heights[1] <= heights[1];
                stored_heights[2] <= heights[2];
                stored_heights[3] <= heights[3];
                stored_heights[4] <= heights[4];
                stored_heights[5] <= heights[5];
                stored_heights[6] <= heights[6];
                stored_heights[7] <= heights[7];
                stored_thickness[0] <= thickness[0];
                stored_thickness[1] <= thickness[1];
                stored_thickness[2] <= thickness[2];
                stored_thickness[3] <= thickness[3];
                stored_thickness[4] <= thickness[4];
                stored_thickness[5] <= thickness[5];
                stored_thickness[6] <= thickness[6];
                stored_thickness[7] <= thickness[7];
            end
            
            BRUTE_FORCE_CHECK: begin
                // Decode ternary combination into book assignments
                if (current_book_idx < stored_num_books) begin
                    book_assignment[current_book_idx] <= combo_temp[1:0];
                    combo_temp <= combo_temp >> 2;
                    current_book_idx <= current_book_idx + 1;
                end
            end
            
            UPDATE_MIN: begin
                // Compute area and update min if valid
                if (valid_assignment && current_area < min_area) begin
                    min_area <= current_area;
                end
                // Reset for next iteration
                current_book_idx <= 3'b0;
            end
            
            DONE: begin
                done <= 1'b1;
            end
        endcase
    end
end

// Next state logic and computation
always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: begin
            if (start) next_state = PREPROCESS;
        end
        
        PREPROCESS: begin
            next_state = BRUTE_FORCE_CHECK;
        end
        
        BRUTE_FORCE_CHECK: begin
            if (current_book_idx == 0 && stored_num_books > 0) begin
                combo_temp = combo_counter;
            end
            
            if (current_book_idx >= stored_num_books) begin
                next_state = UPDATE_MIN;
            end else begin
                next_state = BRUTE_FORCE_CHECK;
            end
        end
        
        UPDATE_MIN: begin
            if (combo_counter >= max_combo) begin
                next_state = DONE;
            end else begin
                next_state = BRUTE_FORCE_CHECK;
            end
        end
        
        DONE: begin
            next_state = DONE;
        end
        
        default: next_state = IDLE;
    endcase
end

// Combinational logic for area calculation
always @(*) begin
    // Initialize max and sum registers
    max_h0 = (book_assignment[0] == 2'b0) ? stored_heights[0] : 8'b0;
    max_h1 = (book_assignment[0] == 2'b1) ? stored_heights[0] : 8'b0;
    max_h2 = (book_assignment[0] == 2'b10) ? stored_heights[0] : 8'b0;
    
    sum_t0 = (book_assignment[0] == 2'b0) ? {8'b0, stored_thickness[0]} : 16'b0;
    sum_t1 = (book_assignment[0] == 2'b1) ? {8'b0, stored_thickness[0]} : 16'b0;
    sum_t2 = (book_assignment[0] == 2'b10) ? {8'b0, stored_thickness[0]} : 16'b0;
    
    // Process remaining books
    // Book 1
    if (stored_num_books > 1) begin
        if (book_assignment[1] == 2'b0) begin
            max_h0 = (stored_heights[1] > max_h0) ? stored_heights[1] : max_h0;
            sum_t0 = sum_t0 + {8'b0, stored_thickness[1]};
        end else if (book_assignment[1] == 2'b1) begin
            max_h1 = (stored_heights[1] > max_h1) ? stored_heights[1] : max_h1;
            sum_t1 = sum_t1 + {8'b0, stored_thickness[1]};
        end else begin
            max_h2 = (stored_heights[1] > max_h2) ? stored_heights[1] : max_h2;
            sum_t2 = sum_t2 + {8'b0, stored_thickness[1]};
        end
    end
    
    // Book 2
    if (stored_num_books > 2) begin
        if (book_assignment[2] == 2'b0) begin
            max_h0 = (stored_heights[2] > max_h0) ? stored_heights[2] : max_h0;
            sum_t0 = sum_t0 + {8'b0, stored_thickness[2]};
        end else if (book_assignment[2] == 2'b1) begin
            max_h1 = (stored_heights[2] > max_h1) ? stored_heights[2] : max_h1;
            sum_t1 = sum_t1 + {8'b0, stored_thickness[2]};
        end else begin
            max_h2 = (stored_heights[2] > max_h2) ? stored_heights[2] : max_h2;
            sum_t2 = sum_t2 + {8'b0, stored_thickness[2]};
        end
    end
    
    // Book 3
    if (stored_num_books > 3) begin
        if (book_assignment[3] == 2'b0) begin
            max_h0 = (stored_heights[3] > max_h0) ? stored_heights[3] : max_h0;
            sum_t0 = sum_t0 + {8'b0, stored_thickness[3]};
        end else if (book_assignment[3] == 2'b1) begin
            max_h1 = (stored_heights[3] > max_h1) ? stored_heights[3] : max_h1;
            sum_t1 = sum_t1 + {8'b0, stored_thickness[3]};
        end else begin
            max_h2 = (stored_heights[3] > max_h2) ? stored_heights[3] : max_h2;
            sum_t2 = sum_t2 + {8'b0, stored_thickness[3]};
        end
    end
    
    // Book 4
    if (stored_num_books > 4) begin
        if (book_assignment[4] == 2'b0) begin
            max_h0 = (stored_heights[4] > max_h0) ? stored_heights[4] : max_h0;
            sum_t0 = sum_t0 + {8'b0, stored_thickness[4]};
        end else if (book_assignment[4] == 2'b1) begin
            max_h1 = (stored_heights[4] > max_h1) ? stored_heights[4] : max_h1;
            sum_t1 = sum_t1 + {8'b0, stored_thickness[4]};
        end else begin
            max_h2 = (stored_heights[4] > max_h2) ? stored_heights[4] : max_h2;
            sum_t2 = sum_t2 + {8'b0, stored_thickness[4]};
        end
    end
    
    // Book 5
    if (stored_num_books > 5) begin
        if (book_assignment[5] == 2'b0) begin
            max_h0 = (stored_heights[5] > max_h0) ? stored_heights[5] : max_h0;
            sum_t0 = sum_t0 + {8'b0, stored_thickness[5]};
        end else if (book_assignment[5] == 2'b1) begin
            max_h1 = (stored_heights[5] > max_h1) ? stored_heights[5] : max_h1;
            sum_t1 = sum_t1 + {8'b0, stored_thickness[5]};
        end else begin
            max_h2 = (stored_heights[5] > max_h2) ? stored_heights[5] : max_h2;
            sum_t2 = sum_t2 + {8'b0, stored_thickness[5]};
        end
    end
    
    // Book 6
    if (stored_num_books > 6) begin
        if (book_assignment[6] == 2'b0) begin
            max_h0 = (stored_heights[6] > max_h0) ? stored_heights[6] : max_h0;
            sum_t0 = sum_t0 + {8'b0, stored_thickness[6]};
        end else if (book_assignment[6] == 2'b1) begin
            max_h1 = (stored_heights[6] > max_h1) ? stored_heights[6] : max_h1;
            sum_t1 = sum_t1 + {8'b0, stored_thickness[6]};
        end else begin
            max_h2 = (stored_heights[6] > max_h2) ? stored_heights[6] : max_h2;
            sum_t2 = sum_t2 + {8'b0, stored_thickness[6]};
        end
    end
    
    // Book 7
    if (stored_num_books > 7) begin
        if (book_assignment[7] == 2'b0) begin
            max_h0 = (stored_heights[7] > max_h0) ? stored_heights[7] : max_h0;
            sum_t0 = sum_t0 + {8'b0, stored_thickness[7]};
        end else if (book_assignment[7] == 2'b1) begin
            max_h1 = (stored_heights[7] > max_h1) ? stored_heights[7] : max_h1;
            sum_t1 = sum_t1 + {8'b0, stored_thickness[7]};
        end else begin
            max_h2 = (stored_heights[7] > max_h2) ? stored_heights[7] : max_h2;
            sum_t2 = sum_t2 + {8'b0, stored_thickness[7]};
        end
    end
    
    // Validate: all shelves must have at least one book
    valid_assignment = 1'b0;
    if (sum_t0 != 0 && sum_t1 != 0 && sum_t2 != 0) begin
        valid_assignment = 1'b1;
    end
    
    // Calculate max thickness
    max_t = sum_t0;
    if (sum_t1 > max_t) max_t = sum_t1;
    if (sum_t2 > max_t) max_t = sum_t2;
    
    // Calculate area: (max_h0 + max_h1 + max_h2) * max_t
    temp_sum_t = max_t;
    temp_max_h = max_h0 + max_h1 + max_h2;
    temp_product = temp_max_h * temp_sum_t;
    current_area = temp_product;
end

// Counter increment logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset handled in main always block
    end else begin
        if (state == UPDATE_MIN && next_state == BRUTE_FORCE_CHECK) begin
            combo_counter <= combo_counter + 1;
        end
    end
end

endmodule