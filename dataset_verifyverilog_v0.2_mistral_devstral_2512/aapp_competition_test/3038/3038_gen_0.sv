module bolt_packer (
    input clk,
    input rst_n,
    input start,
    input [9:0] B,
    input [3:0] num_companies,
    input [3:0] company_index,
    input [3:0] num_packs,
    input [9:0] pack_size [0:9],
    input config_valid,
    output reg [9:0] min_advertised,
    output reg found,
    output reg impossible,
    output reg done
);

    // Parameters
    localparam MAX_COMPANIES = 10;
    localparam MAX_PACKS_PER_COMPANY = 10;
    localparam MAX_BOLTS = 1000;

    // State machine
    typedef enum logic [3:0] {
        IDLE,
        CONFIG,
        PROCESS_COMPANIES,
        FIND_MIN,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Storage for pack sizes and real amounts
    reg [9:0] pack_sizes [0:MAX_COMPANIES-1][0:MAX_PACKS_PER_COMPANY-1];
    reg [9:0] real_amounts [0:MAX_COMPANIES-1][0:MAX_PACKS_PER_COMPANY-1];

    // Counters
    reg [3:0] company_counter;
    reg [3:0] pack_counter;
    reg [3:0] combination_counter;

    // Temporary variables
    reg [9:0] temp_real_amount;
    reg [9:0] temp_min_advertised;
    reg [9:0] temp_combination_sum;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            company_counter <= 0;
            pack_counter <= 0;
            combination_counter <= 0;
            min_advertised <= 0;
            found <= 0;
            impossible <= 0;
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
                if (start) next_state = CONFIG;
            end
            CONFIG: begin
                if (config_valid) begin
                    if (company_index == num_companies - 1 && pack_counter == num_packs - 1) begin
                        next_state = PROCESS_COMPANIES;
                    end
                end else if (!start) begin
                    next_state = IDLE;
                end
            end
            PROCESS_COMPANIES: begin
                if (company_counter == num_companies - 1 && pack_counter == num_packs - 1) begin
                    next_state = FIND_MIN;
                end
            end
            FIND_MIN: begin
                if (company_counter == num_companies - 1 && pack_counter == num_packs - 1) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Configuration state: load pack sizes
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pack_counter <= 0;
        end else if (current_state == CONFIG && config_valid) begin
            pack_sizes[company_index][pack_counter] <= pack_size[pack_counter];
            if (pack_counter < num_packs - 1) begin
                pack_counter <= pack_counter + 1;
            end else begin
                pack_counter <= 0;
            end
        end
    end

    // Process companies state: compute real amounts
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            company_counter <= 0;
            pack_counter <= 0;
            combination_counter <= 0;
        end else if (current_state == PROCESS_COMPANIES) begin
            if (company_counter == 0) begin
                // Manufacturer: real = advertised
                real_amounts[company_counter][pack_counter] <= pack_sizes[company_counter][pack_counter];
            end else begin
                // Compute real amount using greedy approach
                temp_combination_sum = 0;
                temp_real_amount = 0;
                // Find minimal combination of previous company's packs that sum to >= current pack size
                for (int i = 0; i < num_packs; i = i + 1) begin
                    if (temp_combination_sum + real_amounts[company_counter-1][i] >= pack_sizes[company_counter][pack_counter]) begin
                        temp_real_amount = temp_combination_sum + real_amounts[company_counter-1][i];
                        break;
                    end else begin
                        temp_combination_sum = temp_combination_sum + real_amounts[company_counter-1][i];
                    end
                end
                real_amounts[company_counter][pack_counter] <= temp_real_amount;
            end
            // Move to next pack or company
            if (pack_counter < num_packs - 1) begin
                pack_counter <= pack_counter + 1;
            end else begin
                pack_counter <= 0;
                if (company_counter < num_companies - 1) begin
                    company_counter <= company_counter + 1;
                end
            end
        end
    end

    // Find minimum advertised pack size
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            company_counter <= 0;
            pack_counter <= 0;
            temp_min_advertised <= 0;
            found <= 0;
            impossible <= 0;
        end else if (current_state == FIND_MIN) begin
            if (real_amounts[company_counter][pack_counter] >= B) begin
                if (found == 0 || pack_sizes[company_counter][pack_counter] < temp_min_advertised) begin
                    temp_min_advertised = pack_sizes[company_counter][pack_counter];
                    found = 1;
                end
            end
            // Move to next pack or company
            if (pack_counter < num_packs - 1) begin
                pack_counter <= pack_counter + 1;
            end else begin
                pack_counter <= 0;
                if (company_counter < num_companies - 1) begin
                    company_counter <= company_counter + 1;
                end else begin
                    min_advertised <= temp_min_advertised;
                    if (found == 0) impossible <= 1;
                end
            end
        end
    end

    // Done state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else if (current_state == DONE) begin
            done <= 1;
        end else if (current_state != DONE) begin
            done <= 0;
        end
    end

endmodule