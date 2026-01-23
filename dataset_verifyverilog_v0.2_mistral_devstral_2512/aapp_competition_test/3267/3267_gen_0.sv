module chess_spread(
    input clk,
    input rst_n,
    input start,
    input [3:0] board_data,
    input [1:0] board_index,
    output reg [7:0] mirko_spread,
    output reg [7:0] slavko_spread,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        COLLECT,
        COMPUTE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Piece storage (max 4 per player)
    reg [1:0] mirko_row [0:3];
    reg [1:0] mirko_col [0:3];
    reg [1:0] slavko_row [0:3];
    reg [1:0] slavko_col [0:3];
    reg [3:0] mirko_count = 0;
    reg [3:0] slavko_count = 0;

    // Collection counter
    reg [3:0] collect_counter = 0;

    // Compute counters
    reg [1:0] outer_mirko = 0;
    reg [1:0] inner_mirko = 0;
    reg [1:0] outer_slavko = 0;
    reg [1:0] inner_slavko = 0;

    // Temporary spread accumulators
    reg [7:0] temp_mirko_spread = 0;
    reg [7:0] temp_slavko_spread = 0;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            collect_counter <= 0;
            mirko_count <= 0;
            slavko_count <= 0;
            outer_mirko <= 0;
            inner_mirko <= 0;
            outer_slavko <= 0;
            inner_slavko <= 0;
            temp_mirko_spread <= 0;
            temp_slavko_spread <= 0;
            mirko_spread <= 0;
            slavko_spread <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = COLLECT;
            end
            COLLECT: begin
                if (collect_counter == 15) next_state = COMPUTE;
            end
            COMPUTE: begin
                if (outer_mirko == mirko_count && outer_slavko == slavko_count) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Collection logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            collect_counter <= 0;
        end else if (current_state == COLLECT) begin
            if (collect_counter < 16) begin
                // Decode board position
                reg [1:0] row = board_index[1:0];
                reg [1:0] col = board_index[1:0];
                
                // Store piece coordinates
                if (board_data == 1 && mirko_count < 4) begin
                    mirko_row[mirko_count] <= row;
                    mirko_col[mirko_count] <= col;
                    mirko_count <= mirko_count + 1;
                end else if (board_data == 2 && slavko_count < 4) begin
                    slavko_row[slavko_count] <= row;
                    slavko_col[slavko_count] <= col;
                    slavko_count <= slavko_count + 1;
                end
                
                collect_counter <= collect_counter + 1;
            end
        end
    end

    // Compute logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            outer_mirko <= 0;
            inner_mirko <= 0;
            outer_slavko <= 0;
            inner_slavko <= 0;
            temp_mirko_spread <= 0;
            temp_slavko_spread <= 0;
        end else if (current_state == COMPUTE) begin
            // Compute Mirko spread
            if (outer_mirko < mirko_count) begin
                if (inner_mirko < outer_mirko) begin
                    // Calculate distance
                    reg [1:0] r1 = mirko_row[outer_mirko];
                    reg [1:0] c1 = mirko_col[outer_mirko];
                    reg [1:0] r2 = mirko_row[inner_mirko];
                    reg [1:0] c2 = mirko_col[inner_mirko];
                    
                    reg [1:0] diff_r = (r1 > r2) ? (r1 - r2) : (r2 - r1);
                    reg [1:0] diff_c = (c1 > c2) ? (c1 - c2) : (c2 - c1);
                    reg [1:0] distance = (diff_r > diff_c) ? diff_r : diff_c;
                    
                    temp_mirko_spread <= temp_mirko_spread + distance;
                    inner_mirko <= inner_mirko + 1;
                end else begin
                    inner_mirko <= 0;
                    outer_mirko <= outer_mirko + 1;
                end
            end
            
            // Compute Slavko spread
            if (outer_slavko < slavko_count) begin
                if (inner_slavko < outer_slavko) begin
                    // Calculate distance
                    reg [1:0] r1 = slavko_row[outer_slavko];
                    reg [1:0] c1 = slavko_col[outer_slavko];
                    reg [1:0] r2 = slavko_row[inner_slavko];
                    reg [1:0] c2 = slavko_col[inner_slavko];
                    
                    reg [1:0] diff_r = (r1 > r2) ? (r1 - r2) : (r2 - r1);
                    reg [1:0] diff_c = (c1 > c2) ? (c1 - c2) : (c2 - c1);
                    reg [1:0] distance = (diff_r > diff_c) ? diff_r : diff_c;
                    
                    temp_slavko_spread <= temp_slavko_spread + distance;
                    inner_slavko <= inner_slavko + 1;
                end else begin
                    inner_slavko <= 0;
                    outer_slavko <= outer_slavko + 1;
                end
            end
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mirko_spread <= 0;
            slavko_spread <= 0;
            done <= 0;
        end else begin
            case (current_state)
                COMPUTE: begin
                    mirko_spread <= temp_mirko_spread;
                    slavko_spread <= temp_slavko_spread;
                end
                DONE: begin
                    done <= 1;
                end
                default: begin
                    mirko_spread <= 0;
                    slavko_spread <= 0;
                    done <= 0;
                end
            endcase
        end
    end

endmodule