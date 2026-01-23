module bookcase_optimizer (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_books,
    input [7:0] heights [0:7],
    input [7:0] thickness [0:7],
    output reg [15:0] min_area,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        PREPROCESS,
        BRUTE_FORCE_CHECK,
        UPDATE_MIN,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] h_reg [0:7];
    reg [7:0] t_reg [0:7];
    reg [2:0] num_books_reg;

    // Brute force search registers
    reg [15:0] assignment_counter; // 3^8 = 6561 < 2^16
    reg [7:0] book_index;
    reg [1:0] shelf_assignment [0:7];

    // Shelf tracking registers
    reg [7:0] max_height [0:2];
    reg [7:0] total_thickness [0:2];
    reg [7:0] shelf_count [0:2];

    // Current area calculation
    reg [7:0] current_max_height_sum;
    reg [7:0] current_max_thickness;
    reg [15:0] current_area;

    // Control signals
    reg valid_assignment;
    reg new_min_found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            min_area <= 16'hFFFF;
            assignment_counter <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = PREPROCESS;
            end
            PREPROCESS: begin
                next_state = BRUTE_FORCE_CHECK;
            end
            BRUTE_FORCE_CHECK: begin
                if (assignment_counter == 3**num_books_reg - 1) begin
                    next_state = DONE;
                end else begin
                    next_state = UPDATE_MIN;
                end
            end
            UPDATE_MIN: begin
                next_state = BRUTE_FORCE_CHECK;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Preprocessing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 8; i++) begin
                h_reg[i] <= 0;
                t_reg[i] <= 0;
            end
            num_books_reg <= 0;
        end else if (current_state == PREPROCESS) begin
            for (int i = 0; i < 8; i++) begin
                h_reg[i] <= heights[i];
                t_reg[i] <= thickness[i];
            end
            num_books_reg <= num_books;
        end
    end

    // Brute force search logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            assignment_counter <= 0;
            book_index <= 0;
            for (int i = 0; i < 8; i++) begin
                shelf_assignment[i] <= 0;
            end
        end else if (current_state == BRUTE_FORCE_CHECK) begin
            // Initialize for new assignment
            for (int i = 0; i < 3; i++) begin
                max_height[i] <= 0;
                total_thickness[i] <= 0;
                shelf_count[i] <= 0;
            end
            book_index <= 0;
            valid_assignment <= 1;

            // Process current assignment
            for (int i = 0; i < num_books_reg; i++) begin
                reg [1:0] shelf = shelf_assignment[i];
                if (h_reg[i] > max_height[shelf]) begin
                    max_height[shelf] <= h_reg[i];
                end
                total_thickness[shelf] <= total_thickness[shelf] + t_reg[i];
                shelf_count[shelf] <= shelf_count[shelf] + 1;
            end

            // Check if all shelves have at least one book
            valid_assignment = (shelf_count[0] > 0 && shelf_count[1] > 0 && shelf_count[2] > 0);

            // Calculate current area
            current_max_height_sum = max_height[0] + max_height[1] + max_height[2];
            current_max_thickness = (total_thickness[0] > total_thickness[1]) ? 
                                    ((total_thickness[0] > total_thickness[2]) ? total_thickness[0] : total_thickness[2]) :
                                    ((total_thickness[1] > total_thickness[2]) ? total_thickness[1] : total_thickness[2]);
            current_area = current_max_height_sum * current_max_thickness;

            // Update min_area if valid and better
            new_min_found = (valid_assignment && (current_area < min_area));

            // Increment assignment counter
            assignment_counter <= assignment_counter + 1;
        end
    end

    // Update min_area logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_area <= 16'hFFFF;
        end else if (current_state == UPDATE_MIN && new_min_found) begin
            min_area <= current_area;
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else if (current_state == DONE) begin
            done <= 1;
        end else if (current_state == IDLE && start) begin
            done <= 0;
        end
    end

    // Assignment counter to shelf assignments
    always @(*) begin
        reg [15:0] temp_counter = assignment_counter;
        for (int i = 0; i < 8; i++) begin
            shelf_assignment[i] = temp_counter % 3;
            temp_counter = temp_counter / 3;
        end
    end

endmodule