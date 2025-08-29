USE ig_clone;

-- OBJECTIVE QUESTIONS:
-- ANS 1. CHECKING FOR NULL OR DUPLICATE VALUES
-- CHECKING NULL VALUES 
SELECT 
    COUNT(*), COUNT(DISTINCT id)
FROM
    comments;
SELECT 
    COUNT(*), COUNT(DISTINCT id)
FROM
    photos;
SELECT 
    COUNT(*), COUNT(DISTINCT id)
FROM
    tags;
SELECT 
    COUNT(*), COUNT(DISTINCT id)
FROM
    users;
-- CHECKING DUPLICATE VALUES
SELECT comment_text, user_id, photo_id, COUNT(*) 
FROM comments 
GROUP BY comment_text, user_id, photo_id 
HAVING COUNT(*) > 1;
SELECT user_id, photo_id, created_at, COUNT(*) 
FROM likes 
GROUP BY user_id, photo_id, created_at
HAVING COUNT(*) > 1;

-- ANS2. distribution of user activity levels 
SELECT 
    u.id AS user_id,
    u.username,
    COALESCE(p.num_posts, 0) AS total_posts,
    COALESCE(l.num_likes, 0) AS total_likes,
    COALESCE(c.num_comments, 0) AS total_comments
FROM users u
LEFT JOIN (
    SELECT user_id, COUNT(*) AS num_posts
    FROM photos
    GROUP BY user_id
) p ON u.id = p.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS num_likes
    FROM likes
    GROUP BY user_id
) l ON u.id = l.user_id
LEFT JOIN (
    SELECT user_id, COUNT(*) AS num_comments
    FROM comments
    GROUP BY user_id
) c ON u.id = c.user_id
ORDER BY total_posts DESC, total_likes DESC, total_comments DESC;

-- ANS3. the average number of tags per post 
SELECT ROUND(COUNT(tag_id)/ COUNT(DISTINCT photo_id),2) avg_tag_per_post 
FROM photo_tags;

-- ANS4. top users with the highest engagement rates (likes, comments) on their posts and rank them.
WITH engagement AS (
    SELECT 
        u.id,
        u.username,
        p.id AS photo_id,
        COUNT(DISTINCT l.user_id) AS likes,
        COUNT(DISTINCT c.user_id) AS comments
    FROM users u
    LEFT JOIN photos p ON u.id = p.user_id
    JOIN likes l ON l.photo_id = p.id
    JOIN comments c ON c.photo_id = p.id
    GROUP BY u.id, u.username, p.id
)
SELECT 
    id,
    username,
    SUM(likes + comments) AS total_engagement,
    DENSE_RANK() OVER (ORDER BY SUM(likes + comments) DESC) AS engagement_rank
FROM engagement
GROUP BY id, username;

-- ANS5. user has the highest number of followers and followings
WITH follower_counts AS (
    SELECT u.id, u.username,
        COUNT(f.follower_id) AS total_followers FROM users u
    LEFT JOIN follows f ON u.id = f.followee_id
    GROUP BY u.id, u.username
),
following_counts AS (
    SELECT u.id, u.username,
        COUNT(f.followee_id) AS total_followings FROM users u
    LEFT JOIN follows f ON u.id = f.follower_id
    GROUP BY u.id, u.username
),
combined AS (
    SELECT f.id, f.username, f.total_followers, g.total_followings,
        DENSE_RANK() OVER (ORDER BY f.total_followers DESC) AS followers_rank,
        DENSE_RANK() OVER (ORDER BY g.total_followings DESC) AS followings_rank
    FROM follower_counts f
    JOIN following_counts g ON f.id = g.id
)
SELECT id, username, total_followers, total_followings, followers_rank, followings_rank
FROM combined
WHERE followers_rank = 1 OR followings_rank = 1
ORDER BY id;

-- ANS6. average engagement rate (likes, comments) per post for each user.
WITH engagement AS (
    SELECT 
        u.id, u.username, p.id AS photo_id,
        COUNT(DISTINCT l.user_id) AS likes,
        COUNT(DISTINCT c.user_id) AS comments
    FROM users u 
    JOIN photos p ON u.id = p.user_id
    LEFT JOIN likes l ON l.photo_id = p.id
    LEFT JOIN comments c ON c.photo_id = p.id
    GROUP BY u.id, u.username, p.id
)
SELECT id, username,
    ROUND(AVG(likes + comments), 2) AS avg_engagement_per_post
FROM engagement
GROUP BY id, username
ORDER BY avg_engagement_per_post DESC, id ASC;

-- ANS7.list of users who have never liked any post
SELECT id, username
FROM users u 
LEFT JOIN likes l ON l.user_id = u.id
GROUP BY id, username
HAVING COUNT(DISTINCT photo_id) = 0;

-- ANS 8. user-generated content (posts, hashtags, photo tags)
SELECT 
    tag_name,
    COUNT(pt.photo_id) AS num_posts,
    COUNT(DISTINCT p.user_id) AS num_users,
    COUNT(l.photo_id) AS num_likes,
    (COUNT(pt.photo_id) + COUNT(DISTINCT p.user_id) + COUNT(l.photo_id)) AS total_engagement_per_tag
FROM tags t
JOIN photo_tags pt ON t.id = pt.tag_id
JOIN photos p ON pt.photo_id = p.id
JOIN likes l ON pt.photo_id = l.photo_id
GROUP BY tag_name
ORDER BY num_posts DESC, num_users DESC;

-- ANS9. correlations between user activity levels and specific content types 
WITH likes_per_users AS ( SELECT user_id, COUNT(photo_id) AS num_likes FROM likes
    GROUP BY user_id ),
comments_per_posts AS ( SELECT user_id, COUNT(comment_text) AS num_coments_on_posts FROM comments
    GROUP BY user_id ),
posts_per_users AS ( SELECT user_id, COUNT(image_url) AS posts FROM photos
    GROUP BY user_id ),
engagement_per_user AS ( SELECT u.username AS Users_Name, p.user_id, p.id,
        (c1.num_likes + c2.num_coments_on_posts + c3.posts) AS Total_Engagement_rate FROM photos p
    JOIN likes_per_users c1 ON p.user_id = c1.user_id
    JOIN comments_per_posts c2 ON p.user_id = c2.user_id
    JOIN posts_per_users c3 ON p.user_id = c3.user_id
    JOIN users u ON p.user_id = u.id
    GROUP BY u.username, p.user_id, p.id, c1.num_likes, c2.num_coments_on_posts, c3.posts ),
engagement_percentage AS ( SELECT Users_Name,
        ROUND(SUM(c1.num_likes) * 100.0 / SUM(Total_Engagement_rate), 2) AS num_likes_percent,
        ROUND(SUM(c3.posts) * 100.0 / SUM(Total_Engagement_rate), 2) AS posts_percent,
        ROUND(SUM(c2.num_coments_on_posts) * 100.0 / SUM(Total_Engagement_rate), 2) AS comment_percent,
        100.0 AS total_engagement_percent
    FROM engagement_per_user c4
    JOIN likes_per_users c1 ON c4.user_id = c1.user_id
    JOIN comments_per_posts c2 ON c4.user_id = c2.user_id
    JOIN posts_per_users c3 ON c4.user_id = c3.user_id
    GROUP BY Users_Name )
SELECT *, DENSE_RANK() OVER (
        ORDER BY total_engagement_percent DESC, posts_percent DESC, num_likes_percent DESC ) AS ranks
FROM engagement_percentage
ORDER BY ranks LIMIT 10;

-- ANS10. total number of likes, comments, and photo tags for each user.
SELECT user_id, username, 
       SUM(likes) AS likes,
       SUM(comments) AS comments,
       SUM(tags) AS tags
FROM (
	SELECT u.id AS user_id, u.username, p.id AS photo_id,
	    COUNT(DISTINCT l.user_id) AS likes,
	    COUNT(DISTINCT c.id) AS comments,
	    COUNT(DISTINCT pt.tag_id) AS tags
	FROM users u 
	JOIN photos p ON u.id = p.user_id
	JOIN photo_tags pt ON p.id = pt.photo_id
	JOIN likes l ON pt.photo_id = l.photo_id
	JOIN comments c ON pt.photo_id = c.photo_id
	GROUP BY u.id, u.username, p.id
) ttl
GROUP BY user_id, username;

-- ANS 11. Rank users based on their total engagement (likes, comments, shares) over a month.
WITH engagement AS (
    SELECT u.id AS user_id, u.username,
        MONTH(p.created_dat) AS `month`,
        YEAR(p.created_dat) AS `year`,
        p.id AS photo_id,
        (COUNT(DISTINCT c.user_id) + COUNT(DISTINCT l.user_id)) AS engagement_recieved
    FROM users u 
    LEFT JOIN photos p ON u.id = p.user_id
    LEFT JOIN comments c ON c.photo_id = p.id
    LEFT JOIN likes l ON l.photo_id = p.id
    GROUP BY u.id, u.username, MONTH(p.created_dat), YEAR(p.created_dat), p.id
)
SELECT user_id, username, `year`, `month`,
    SUM(engagement_recieved) AS total_engagement,
    DENSE_RANK() OVER (ORDER BY SUM(engagement_recieved) DESC) AS engagement_rank
FROM engagement
GROUP BY user_id, username, `year`, `month`
ORDER BY total_engagement DESC;

-- ANS12. hashtags that have been used in posts with the highest average number of likes.
WITH likes_per_photo AS (
    SELECT photo_id, 
        COUNT(user_id) AS num_likes
    FROM likes
    GROUP BY photo_id
),
avg_likes_per_tag_rank AS (
    SELECT tag_name, 
        ROUND(AVG(num_likes), 2) AS Avg_num_likes,
        DENSE_RANK() OVER (ORDER BY AVG(num_likes) DESC) AS Tag_avg_likes_rank
    FROM likes_per_photo c1
    JOIN photo_tags p ON c1.photo_id = p.photo_id
    JOIN tags t ON t.id = p.tag_id
    GROUP BY tag_name
)
SELECT 
    UPPER(tag_name) AS Max_liked_tag,
    Avg_num_likes AS Max_Avg_num_likes,
    Tag_avg_likes_rank
FROM avg_likes_per_tag_rank
WHERE Tag_avg_likes_rank = 1
ORDER BY Max_Avg_num_likes;

-- ANS13. users who have started following someone after being followed by that person
WITH mutual_followbacks AS (
    SELECT DISTINCT
        f1.follower_id AS user_followed_back,
        f1.followee_id AS initial_follower
    FROM follows f1
    JOIN follows f2 
        ON f1.followee_id = f2.follower_id
       AND f1.follower_id = f2.followee_id
       AND f1.follower_id != f1.followee_id
)
SELECT DISTINCT
    u.username AS user_who_followed_back
FROM mutual_followbacks mf
JOIN users u ON mf.user_followed_back = u.id
ORDER BY 1;


-- SUBJECTIVE ANSWERS 

-- ANS1.Based on user engagement and activity levels,the most loyal or valuable users
WITH total_likes_per_user AS (
    SELECT user_id, COUNT(photo_id) AS num_likes FROM likes
    GROUP BY user_id ),
total_comments_per_user AS (
    SELECT user_id, COUNT(comment_text) AS num_coments_per_users FROM comments
    GROUP BY user_id ),
total_post_per_user AS (
    SELECT user_id, COUNT(image_url) AS num_posts FROM photos
    GROUP BY user_id ),
Users_Activity_Engagement AS ( SELECT u.username,
        SUM(num_posts + num_coments_per_users + num_likes) AS activity_level_users,
        SUM(num_coments_per_users + num_likes) AS Engagement_rate
    FROM users u
    JOIN total_likes_per_user c1 ON u.id = c1.user_id
    JOIN total_comments_per_user c2 ON u.id = c2.user_id
    JOIN total_post_per_user c3 ON u.id = c3.user_id
    GROUP BY u.username )
SELECT *,
    DENSE_RANK() OVER (ORDER BY activity_level_users DESC, Engagement_rate DESC) AS users_ranking
FROM Users_Activity_Engagement
WHERE activity_level_users > (SELECT AVG(activity_level_users) FROM Users_Activity_Engagement)
AND Engagement_rate > (SELECT AVG(Engagement_rate) FROM Users_Activity_Engagement)
ORDER BY users_ranking;

-- ANS2. INACTIVE USERS
WITH user_category AS (
    SELECT DISTINCT u.id, u.username,
        CASE WHEN p.id IS NULL THEN 'Inactive User'
            ELSE 'Active User'
        END AS User_Category
    FROM users u
    LEFT JOIN photos p ON u.id = p.user_id
)
SELECT id, username
FROM user_category 
WHERE User_Category = 'Inactive User';

-- ANS 3. tags have the highest engagement rates
SELECT 
    t.tag_name AS popular_hashtag,
    COUNT(*) AS total_usage_count
FROM photo_tags pt
JOIN tags t ON pt.tag_id = t.id
GROUP BY t.tag_name
ORDER BY total_usage_count DESC
LIMIT 10;

-- ANS4. Trend between users engagement and posting times
WITH time_of_likes AS (
    SELECT photo_id,
        TIME(created_at) AS likes_time,
        COUNT(photo_id) AS num_likes
    FROM likes
    GROUP BY photo_id, TIME(created_at)
),
time_of_comments AS (
    SELECT photo_id,
        TIME(created_at) AS comments_time,
        COUNT(comment_text) AS num_coments_per_users
    FROM comments
    GROUP BY photo_id, TIME(created_at)
),
time_based_engagement AS (
    SELECT TIME(p.created_dat) AS post_time,
        comments_time, likes_time,
        SUM(num_coments_per_users + num_likes) AS Engagement_rate
    FROM photos p
    JOIN time_of_likes c1 ON p.id = c1.photo_id
    JOIN time_of_comments c2 ON p.id = c2.photo_id
    GROUP BY TIME(p.created_dat), comments_time, likes_time
)
SELECT *
FROM time_based_engagement
ORDER BY post_time;

-- ANS5. INFLUENCER MARKETING CAMPAINGS
WITH follower_metrics AS (
    SELECT followee_id AS user_id,
        COUNT(DISTINCT follower_id) AS total_followers FROM follows
    GROUP BY followee_id ),
likes_received AS (
    SELECT user_id,
        COUNT(photo_id) AS total_likes FROM likes
    GROUP BY user_id ),
comments_received AS (
    SELECT user_id,
        COUNT(comment_text) AS total_comments FROM comments
    GROUP BY user_id ),
influencer_ranking AS (
    SELECT u.username AS influencer_username, f.total_followers,
        SUM(l.total_likes + c.total_comments) AS total_engagement,
        DENSE_RANK() OVER (
            ORDER BY SUM(l.total_likes + c.total_comments) DESC, f.total_followers DESC
        ) AS influencer_rank FROM users u
    JOIN follower_metrics f ON u.id = f.user_id
    JOIN likes_received l ON u.id = l.user_id
    JOIN comments_received c ON u.id = c.user_id
    GROUP BY u.username, f.total_followers )
SELECT * FROM influencer_ranking
ORDER BY influencer_rank
LIMIT 10;

-- ANS 6. SEGMENTATION OF USER BASED ON  USER BEHAVIOUR AND ENGAGEMENT DATA 
WITH user_likes AS (
    SELECT user_id, COUNT(photo_id) AS total_likes FROM likes
    GROUP BY user_id ),
user_comments AS (
    SELECT user_id, COUNT(comment_text) AS total_comments FROM comments
    GROUP BY user_id ),
user_tags AS (
    SELECT t.tag_name, p.user_id FROM tags t
    JOIN photo_tags pt ON t.id = pt.tag_id
    JOIN photos p ON pt.photo_id = p.id ),
user_tag_engagement AS (
    SELECT u.username AS username, ut.tag_name AS top_tag,
        SUM(uc.total_comments + ul.total_likes) AS tag_engagement_score,
        DENSE_RANK() OVER (PARTITION BY u.username ORDER BY SUM(uc.total_comments + ul.total_likes) DESC) AS tag_rank
    FROM users u
    JOIN user_likes ul ON u.id = ul.user_id
    JOIN user_comments uc ON u.id = uc.user_id
    JOIN user_tags ut ON u.id = ut.user_id
    GROUP BY u.username, ut.tag_name
)
SELECT * FROM user_tag_engagement
WHERE tag_rank = 1
ORDER BY tag_engagement_score DESC, username;



-- THE END...
