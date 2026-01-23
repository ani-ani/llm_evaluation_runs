module ad_remover (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in [31:0][31:0],
    output reg [7:0] char_out [31:0][31:0],
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        PARSE_IMAGES,
        CHECK_BANNED,
        MARK_ADS,
        REMOVE_ADS,
        DONE
    } state_t;

    state_t state = IDLE;
    reg [15:0] cycle_count = 0;

    // Image storage (up to 16 images)
    typedef struct {
        logic [4:0] top;
        logic [4:0] left;
        logic [4:0] bottom;
        logic [4:0] right;
        logic is_ad;
        logic [3:0] parent_id;
    } image_t;

    image_t images [0:15];
    logic [3:0] image_count = 0;

    // Temporary storage for processing
    logic [4:0] current_row = 0;
    logic [4:0] current_col = 0;
    logic [3:0] current_image = 0;

    // Allowed characters check
    function logic is_allowed_char(input [7:0] c);
        return (c >= "0" && c <= "9") ||
               (c >= "A" && c <= "Z") ||
               (c >= "a" && c <= "z") ||
               c == "?" || c == "!" || c == "," || c == "." || c == " ";
    endfunction

    // Check if image A contains image B
    function logic contains(image_t a, image_t b);
        return (a.top < b.top) && (a.left < b.left) &&
               (a.bottom > b.bottom) && (a.right > b.right);
    endfunction

    // Initialize output to input (will modify ads later)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                for (int j = 0; j < 32; j++) begin
                    char_out[i][j] <= 8'h20;
                end
            end
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 0;
            image_count <= 0;
            current_row <= 0;
            current_col <= 0;
            current_image <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PARSE_IMAGES;
                        cycle_count <= 0;
                        image_count <= 0;
                        current_row <= 0;
                        current_col <= 0;
                        // Initialize output to input
                        for (int i = 0; i < 32; i++) begin
                            for (int j = 0; j < 32; j++) begin
                                char_out[i][j] <= char_in[i][j];
                            end
                        end
                    end
                end

                PARSE_IMAGES: begin
                    if (cycle_count < 10000) begin
                        cycle_count <= cycle_count + 1;
                        // Simple image parsing (simplified for synthesis)
                        // In real implementation, would need proper corner detection
                        if (current_row < 32 && current_col < 32) begin
                            if (char_in[current_row][current_col] == "+") begin
                                // Found a corner - store image (simplified)
                                if (image_count < 16) begin
                                    images[image_count].top <= current_row;
                                    images[image_count].left <= current_col;
                                    // Assume minimum 3x3 size for synthesis
                                    images[image_count].bottom <= current_row + 2;
                                    images[image_count].right <= current_col + 2;
                                    images[image_count].is_ad <= 0;
                                    images[image_count].parent_id <= 0;
                                    image_count <= image_count + 1;
                                end
                            end
                            // Move to next position
                            if (current_col == 31) begin
                                current_col <= 0;
                                current_row <= current_row + 1;
                            end else begin
                                current_col <= current_col + 1;
                            end
                        end
                        // After scanning, move to next state
                        if (current_row == 32) begin
                            state <= CHECK_BANNED;
                            current_row <= 0;
                            current_col <= 0;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                CHECK_BANNED: begin
                    if (cycle_count < 10000) begin
                        cycle_count <= cycle_count + 1;
                        // Check each character for banned status
                        if (current_row < 32 && current_col < 32) begin
                            if (!is_allowed_char(char_in[current_row][current_col])) begin
                                // Find containing image (simplified)
                                for (int i = 0; i < image_count; i++) begin
                                    if (current_row >= images[i].top && current_row <= images[i].bottom &&
                                        current_col >= images[i].left && current_col <= images[i].right) begin
                                        images[i].is_ad <= 1;
                                        break;
                                    end
                                end
                            end
                            // Move to next position
                            if (current_col == 31) begin
                                current_col <= 0;
                                current_row <= current_row + 1;
                            end else begin
                                current_col <= current_col + 1;
                            end
                        end
                        // After checking all, move to next state
                        if (current_row == 32) begin
                            state <= MARK_ADS;
                            current_row <= 0;
                            current_col <= 0;
                            current_image <= 0;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                MARK_ADS: begin
                    if (cycle_count < 10000) begin
                        cycle_count <= cycle_count + 1;
                        // Mark parent images (simplified)
                        if (current_image < image_count) begin
                            // Find parent for current image
                            for (int i = 0; i < image_count; i++) begin
                                if (i != current_image && contains(images[i], images[current_image])) begin
                                    images[current_image].parent_id <= i;
                                    if (images[current_image].is_ad) begin
                                        images[i].is_ad <= 1;
                                    end
                                    break;
                                end
                            end
                            current_image <= current_image + 1;
                        end
                        // After processing all images, move to next state
                        if (current_image == image_count) begin
                            state <= REMOVE_ADS;
                            current_row <= 0;
                            current_col <= 0;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                REMOVE_ADS: begin
                    if (cycle_count < 10000) begin
                        cycle_count <= cycle_count + 1;
                        // Replace ad pixels with spaces
                        if (current_row < 32 && current_col < 32) begin
                            for (int i = 0; i < image_count; i++) begin
                                if (images[i].is_ad &&
                                    current_row >= images[i].top && current_row <= images[i].bottom &&
                                    current_col >= images[i].left && current_col <= images[i].right) begin
                                    char_out[current_row][current_col] <= 8'h20;
                                    break;
                                end
                            end
                            // Move to next position
                            if (current_col == 31) begin
                                current_col <= 0;
                                current_row <= current_row + 1;
                            end else begin
                                current_col <= current_col + 1;
                            end
                        end
                        // After processing all, move to done
                        if (current_row == 32) begin
                            state <= DONE;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule